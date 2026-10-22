#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f Assets/Clipmio.icns ] || [ Sources/Clipmio/Resources/ClipmioLogo.png -nt Assets/Clipmio.icns ] || [ scripts/make-icon.sh -nt Assets/Clipmio.icns ]; then
  bash scripts/make-icon.sh
fi

build_args=(-project Clipmio.xcodeproj -scheme Clipmio -configuration Release
  -derivedDataPath build/DerivedData -destination 'generic/platform=macOS')
if [ "${UNIVERSAL:-0}" = "1" ]; then
  build_args+=(ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO)
else
  build_args+=("ARCHS=$(uname -m)" ONLY_ACTIVE_ARCH=YES)
fi

xcodebuild "${build_args[@]}" build
mkdir -p dist
app="dist/Clipmio.app"
rm -rf "$app"
ditto build/DerivedData/Build/Products/Release/Clipmio.app "$app"
codesign --verify --strict --verbose=2 "$app"
plutil -lint "$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
archive="dist/Clipmio-$version.zip"
rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
shasum -a 256 "$archive"
echo "Built $app (local ad-hoc signature; not notarized)."
