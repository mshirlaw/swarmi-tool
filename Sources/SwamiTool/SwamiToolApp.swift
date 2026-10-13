// Swami 5000 Tool: updates course data and firmware on a Swami golf GPS device.
// Finds the USB drive labelled "SWAMI", then downloads
//   Course.map   -> /Volumes/SWAMI/Course/Course.map
//   fw_swami.bin -> /Volumes/SWAMI/Update/fw_GOLF_RES.bin
// A failed download leaves no partial file behind.

import SwiftUI
import os

let log = Logger(subsystem: "SwamiTool", category: "update")

let volumeURL = URL(fileURLWithPath: "/Volumes/SWAMI")
let courseURL = URL(string: "http://golftracker.izzo.com/GolfTrackerWeb/file/Course.map")!
let firmwareURL = URL(string: "http://golftracker.izzo.com/GolfTrackerWeb/file/fw_swami.bin")!

@MainActor
final class Model: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var connected = false
    @Published var busy = false
    @Published var progress = 0.0
    @Published var status = ""

    private var timer: Timer?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    override init() {
        super.init()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        var isDir: ObjCBool = false
        connected = FileManager.default.fileExists(atPath: volumeURL.path, isDirectory: &isDir) && isDir.boolValue
    }

    func start(_ url: URL, to relativePath: String) {
        guard connected, !busy else { return }
        let dest = volumeURL.appendingPathComponent(relativePath)
        do {
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            status = "Could not write to the SWAMI drive: \(error.localizedDescription)"
            return
        }
        log.notice("start \(url.lastPathComponent, privacy: .public) -> \(dest.path, privacy: .public)")
        busy = true
        progress = 0
        status = "Downloading... please wait"
        let task = session.downloadTask(with: url)
        task.taskDescription = dest.path  // read back off the main thread when the download finishes
        task.resume()
    }

    // MARK: URLSessionDownloadDelegate (called off the main thread)

    nonisolated func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64,
                                totalBytesWritten written: Int64, totalBytesExpectedToWrite total: Int64) {
        guard total > 0 else { return }
        Task { @MainActor in self.progress = Double(written) / Double(total) }
    }

    nonisolated func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo tmp: URL) {
        // The temp file is deleted when this returns, so move it here.
        let http = downloadTask.response as? HTTPURLResponse
        guard http?.statusCode == 200 else {
            finish("Download failed: server returned \(http?.statusCode ?? 0)")
            return
        }
        log.notice("downloaded \(downloadTask.countOfBytesReceived) bytes, http \(http?.statusCode ?? 0), main thread: \(Thread.isMainThread)")
        guard let path = downloadTask.taskDescription else { return }
        let dest = URL(fileURLWithPath: path)
        // Copying onto the USB drive is slow, so do it here (background queue), never on the main thread.
        Task { @MainActor in
            self.progress = 0
            self.status = "Copying to SWAMI... do not unplug"
        }
        do {
            try? FileManager.default.removeItem(at: dest)
            let t0 = Date()
            try copy(tmp, to: dest)
            log.notice("copy to device took \(Date().timeIntervalSince(t0), format: .fixed(precision: 1))s")
            finish("Download completed! Eject SWAMI before unplugging.", ok: true)
        } catch {
            try? FileManager.default.removeItem(at: dest)
            finish("Download failed: \(error.localizedDescription)")
        }
    }

    /// Copies in 1 MB chunks, reporting progress, then flushes to the device before returning.
    nonisolated private func copy(_ src: URL, to dest: URL) throws {
        let total = (try FileManager.default.attributesOfItem(atPath: src.path)[.size] as? Int64) ?? 0
        guard FileManager.default.createFile(atPath: dest.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let input = try FileHandle(forReadingFrom: src)
        let output = try FileHandle(forWritingTo: dest)
        defer { try? input.close(); try? output.close() }

        let start = Date()
        var written: Int64 = 0
        var lastReport = Date.distantPast
        while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty {
            try output.write(contentsOf: chunk)
            written += Int64(chunk.count)
            let now = Date()
            if now.timeIntervalSince(lastReport) >= 0.25 {
                lastReport = now
                report(written: written, total: total, since: start)
            }
        }
        report(written: written, total: total, since: start)
        // Make sure the data is really on the drive before we say "done".
        try output.synchronize()
    }

    nonisolated private func report(written: Int64, total: Int64, since start: Date) {
        let mb = { (n: Int64) in String(format: "%.1f", Double(n) / 1_048_576) }
        let rate = Double(written) / 1_048_576 / max(Date().timeIntervalSince(start), 0.001)
        let message = "Copying to SWAMI... \(mb(written)) of \(mb(total)) MB (\(String(format: "%.1f", rate)) MB/s) - do not unplug"
        Task { @MainActor in
            if total > 0 { self.progress = Double(written) / Double(total) }
            self.status = message
        }
    }

    nonisolated func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish("Download failed: \(error.localizedDescription)") }
    }

    nonisolated private func finish(_ message: String, ok: Bool = false) {
        log.notice("finish ok=\(ok): \(message, privacy: .public)")
        Task { @MainActor in
            self.busy = false
            self.status = message
            if ok { self.progress = 1 }
        }
    }
}

struct ContentView: View {
    @StateObject private var model = Model()

    var body: some View {
        VStack(spacing: 14) {
            Text("Swami 5000 Tool v1.01").font(.title2).bold()

            Label(model.connected ? "USB Connected" : "USB Disconnected",
                  systemImage: model.connected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(model.connected ? .green : .red)
            if !model.connected {
                Text("Plug in your SWAMI device and choose USB storage mode.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            Group {
                Button("Update Course") { model.start(courseURL, to: "Course/Course.map") }
                Button("Update Firmware") { model.start(firmwareURL, to: "Update/fw_GOLF_RES.bin") }
            }
            .frame(width: 220).controlSize(.large)
            .disabled(!model.connected || model.busy)

            ProgressView(value: model.progress).padding(.horizontal)
            Text(model.status).font(.callout).multilineTextAlignment(.center).frame(minHeight: 40)
        }
        .padding(24)
        .frame(width: 380)
    }
}

@main
struct SwamiToolApp: App {
    var body: some Scene {
        WindowGroup("Swami 5000 Tool") { ContentView() }
            .windowResizability(.contentSize)
    }
}
