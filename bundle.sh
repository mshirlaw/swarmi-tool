#!/bin/sh
# Builds "Swami 5000 Tool.app" (universal: Apple Silicon + Intel).
set -e
cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
APP="Swami 5000 Tool.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Icon/AppIcon.icns "$APP/Contents/Resources/"
cp "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/SwamiTool" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Swami 5000 Tool</string>
<key>CFBundleIdentifier</key><string>local.swami5000tool</string>
<key>CFBundleExecutable</key><string>SwamiTool</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>1.0.1</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
<key>NSRemovableVolumesUsageDescription</key><string>Copies course and firmware files to your SWAMI device.</string>
</dict></plist>
P
codesign --force --sign - "$APP"
echo "Built: $PWD/$APP"
