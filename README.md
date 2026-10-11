# Swami 5000 Tool

A small macOS app, written in Swift/SwiftUI, for updating the course data and firmware on a Swami golf GPS device.

## What it does

1. Watches for a USB drive named `SWAMI` (the device in USB storage mode) at `/Volumes/SWAMI`.
2. **Update Course** downloads `Course.map` to `/Volumes/SWAMI/Course/Course.map`.
3. **Update Firmware** downloads `fw_swami.bin` to `/Volumes/SWAMI/Update/fw_GOLF_RES.bin`.
4. Shows connection state, download progress and status. A failed download leaves no partial file on the device.

Downloads come from `http://golftracker.izzo.com/GolfTrackerWeb/file/` (plain HTTP, so the app allows insecure loads and does not verify the files).

## Using it

1. Plug in the device and choose USB storage mode.
2. Open the app and wait for **USB Connected**.
3. Click **Update Course** or **Update Firmware**.
4. When it says completed, eject `SWAMI` in Finder before unplugging.

macOS may ask for access to removable volumes the first time. Click Allow.

## Building

Requires macOS 13+ and the Swift toolchain (Xcode or Command Line Tools).

```sh
./bundle.sh
```

This builds a universal (Apple Silicon + Intel) binary and produces `Swami 5000 Tool.app` with the icon and an ad-hoc signature. You can also open `Package.swift` in Xcode.

## Distributing

The app is not signed with an Apple Developer ID or notarized, so Gatekeeper blocks a plain double-click on another Mac.

1. Zip it: `ditto -c -k --keepParent "Swami 5000 Tool.app" "Swami 5000 Tool.zip"`
2. Send the zip. The recipient unzips it and drags the app to Applications.
3. First launch only: right-click the app, choose **Open**, then **Open** again. (Or System Settings → Privacy & Security → **Open Anyway**.)

To remove the warning entirely, sign and notarize with an Apple Developer account ($99/year).

## Layout

| Path | Purpose |
| --- | --- |
| `Sources/SwamiTool/SwamiToolApp.swift` | The whole app (model, download logic, UI) |
| `Package.swift` | Swift Package Manager manifest |
| `bundle.sh` | Builds the `.app` bundle |
| `Icon/make_icon.swift` | Draws the app icon in code |
| `Icon/build_icns.sh` | Regenerates `Icon/AppIcon.icns` |
