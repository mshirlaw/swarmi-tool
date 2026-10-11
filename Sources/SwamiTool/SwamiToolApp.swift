// Swami 5000 Tool: updates course data and firmware on a Swami golf GPS device.
// Finds the USB drive labelled "SWAMI", then downloads
//   Course.map   -> /Volumes/SWAMI/Course/Course.map
//   fw_swami.bin -> /Volumes/SWAMI/Update/fw_GOLF_RES.bin
// A failed download leaves no partial file behind.

import SwiftUI

let volumeURL = URL(fileURLWithPath: "/Volumes/SWAMI")
let courseURL = URL(string: "http://golftracker.izzo.com/GolfTrackerWeb/file/Course.map")!
let firmwareURL = URL(string: "http://golftracker.izzo.com/GolfTrackerWeb/file/fw_swami.bin")!

@MainActor
final class Model: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var connected = false
    @Published var busy = false
    @Published var progress = 0.0
    @Published var status = ""

    private var destination: URL?
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
        destination = dest
        busy = true
        progress = 0
        status = "Downloading... please wait"
        session.downloadTask(with: url).resume()
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
        DispatchQueue.main.sync {
            guard let dest = self.destination else { return }
            do {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmp, to: dest)
                self.finish("Download completed! Eject SWAMI before unplugging.", ok: true)
            } catch {
                try? FileManager.default.removeItem(at: dest)
                self.finish("Download failed: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish("Download failed: \(error.localizedDescription)") }
    }

    nonisolated private func finish(_ message: String, ok: Bool = false) {
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
