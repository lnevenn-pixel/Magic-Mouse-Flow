#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
output_dir="$project_dir/outputs"
app_dir="$output_dir/Magic Mouse Flow.app"

cd "$project_dir"
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"

mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
cp "$binary_dir/MagicMouseFlow" "$app_dir/Contents/MacOS/MagicMouseFlow"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c 'Clear dict' "$app_dir/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :CFBundleName string Magic Mouse Flow' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string Magic Mouse Flow' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string com.magicmouseflow.app' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string MagicMouseFlow' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon.icns' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 0.5.2' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 10' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 13.0' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSHumanReadableCopyright string Copyright 2026' "$app_dir/Contents/Info.plist"

# A persistent local certificate gives TCC (Accessibility/Input Monitoring) a
# stable identity across rebuilds. Fall back to a stable ad-hoc requirement on
# machines where that development certificate has not been installed.
signing_identity="Magic Mouse Flow Local Signing"
if security find-identity -v -p codesigning | grep -Fq "\"$signing_identity\""; then
  codesign --force --deep --options runtime --timestamp=none \
    --sign "$signing_identity" --identifier com.magicmouseflow.app "$app_dir"
else
  codesign --force --deep --sign - \
    --identifier com.magicmouseflow.app \
    --requirements '=designated => identifier "com.magicmouseflow.app"' \
    "$app_dir"
fi
echo "$app_dir"
