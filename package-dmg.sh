#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "package-dmg.sh requires macOS." >&2
    exit 1
fi
if ! command -v hdiutil >/dev/null 2>&1; then
    echo "hdiutil was not found; macOS Command Line Tools are required." >&2
    exit 1
fi

version="${VERSION:-1.0.0}"
configuration="${CONFIGURATION:-release}"
volume_name="QuickTab"
dist_dir="$PWD/dist"
staging_dir="$dist_dir/.dmg-staging"
app_path="$dist_dir/QuickTab.app"
dmg_path="$dist_dir/QuickTab-${version}.dmg"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)?$ ]] || {
    echo "VERSION must use semver, for example 1.0.0." >&2
    exit 1
}

CONFIGURATION="$configuration" ./build.sh

app_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PWD/Resources/Info.plist")"
[[ "$app_version" == "$version" ]] || {
    echo "VERSION ($version) does not match CFBundleShortVersionString ($app_version)." >&2
    exit 1
}

rm -rf "$staging_dir"
mkdir -p "$staging_dir"
cp -R "$app_path" "$staging_dir/QuickTab.app"
ln -s /Applications "$staging_dir/Applications"

rm -f "$dmg_path"
hdiutil create \
    -volname "$volume_name" \
    -srcfolder "$staging_dir" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$dmg_path"

hdiutil verify "$dmg_path"
codesign --verify --strict --verbose=2 "$app_path"
plutil -lint "$app_path/Contents/Info.plist"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_path/Contents/Info.plist")"
[[ "$bundle_id" == "com.local.quicktab" ]] || {
    echo "Invalid bundle identifier: $bundle_id" >&2
    exit 1
}

mount_point="$(mktemp -d /tmp/quicktab-dmg-mount.XXXXXX)"
cleanup() {
    hdiutil detach "$mount_point" -quiet >/dev/null 2>&1 || true
    rm -rf "$mount_point" "$staging_dir"
}
trap cleanup EXIT
hdiutil attach "$dmg_path" -nobrowse -readonly -mountpoint "$mount_point" >/dev/null
[[ -d "$mount_point/QuickTab.app" ]] || { echo "DMG is missing QuickTab.app." >&2; exit 1; }
[[ -L "$mount_point/Applications" ]] || { echo "DMG is missing the Applications alias." >&2; exit 1; }
[[ -f "$mount_point/QuickTab.app/Contents/Resources/AppIcon.icns" ]] || { echo "DMG is missing AppIcon.icns." >&2; exit 1; }

echo "Created and verified: $dmg_path"
