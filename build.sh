#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != Darwin ]]; then echo 'QuickTab requires macOS 14 or newer.' >&2; exit 1; fi
if ! xcrun --find swift >/dev/null 2>&1 || ! xcrun --show-sdk-path >/dev/null 2>&1; then
    echo 'Swift or the macOS SDK is missing. Run xcode-select --install.' >&2; exit 1
fi
configuration="${CONFIGURATION:-debug}"
if [[ "$configuration" != debug && "$configuration" != release ]]; then echo 'CONFIGURATION must be debug or release.' >&2; exit 1; fi
architectures="${ARCHS:-native}"
build_binary() {
    local architecture="$1"
    local build_path=".build"
    local triple_args=()
    if [[ "$architecture" != "native" ]]; then
        build_path=".build-$architecture"
        triple_args=(--triple "${architecture}-apple-macosx14.0")
    fi
    if [[ "$architecture" == "native" ]]; then
        SWIFT_BUILD_PATH="$build_path" swift build -c "$configuration" >&2
        SWIFT_BUILD_PATH="$build_path" swift build -c "$configuration" --show-bin-path
    else
        SWIFT_BUILD_PATH="$build_path" swift build -c "$configuration" "${triple_args[@]}" >&2
        SWIFT_BUILD_PATH="$build_path" swift build -c "$configuration" "${triple_args[@]}" --show-bin-path
    fi
}
case "$architectures" in
    native)
        bin_dir="$(build_binary native)"
        binary_paths=("$bin_dir/QuickTab")
        ;;
    arm64,x86_64|x86_64,arm64)
        binary_paths=()
        for architecture in arm64 x86_64; do
            bin_dir="$(build_binary "$architecture")"
            binary_paths+=("$bin_dir/QuickTab")
        done
        ;;
    *)
        echo 'ARCHS must be native or arm64,x86_64.' >&2
        exit 1
        ;;
esac
app_dir="$PWD/dist/QuickTab.app"
icon_path="$PWD/Resources/AppIcon.icns"
[[ -f "$icon_path" ]] || { echo "Resources/AppIcon.icns is missing. Run iconutil before building." >&2; exit 1; }
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
if [[ "${#binary_paths[@]}" -eq 1 ]]; then
    cp "${binary_paths[0]}" "$app_dir/Contents/MacOS/QuickTab"
else
    lipo -create "${binary_paths[@]}" -output "$app_dir/Contents/MacOS/QuickTab"
fi
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp "$icon_path" "$app_dir/Contents/Resources/AppIcon.icns"
plutil -lint "$app_dir/Contents/Info.plist"
identity="${SIGNING_IDENTITY:--}"
if [[ "$identity" == '-' ]]; then
    echo 'Using ad-hoc signing; macOS may request permissions again after a rebuild.'
    codesign --force --sign - --entitlements Resources/QuickTab.entitlements "$app_dir"
else
    codesign --force --sign "$identity" --entitlements Resources/QuickTab.entitlements "$app_dir"
fi
codesign --verify --strict --verbose=2 "$app_dir"
actual_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_dir/Contents/Info.plist")"
[[ "$actual_id" == com.local.quicktab ]] || { echo 'Invalid bundle identifier.' >&2; exit 1; }
[[ -f "$app_dir/Contents/Resources/AppIcon.icns" ]] || { echo 'AppIcon.icns is missing from the app bundle.' >&2; exit 1; }
echo "Success: $app_dir"
