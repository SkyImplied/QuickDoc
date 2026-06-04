#!/usr/bin/env bash
set -euo pipefail

APP_NAME="QuickDoc"
SCHEME_NAME="QuickDoc"
PROJECT_NAME="QuickDoc.xcodeproj"
CONFIGURATION="Release"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build"
DERIVED_DATA_PATH="$BUILD_ROOT/ReleaseDerivedData"
DIST_DIR="$BUILD_ROOT/release"
STAGE_DIR="$DIST_DIR/dmg-root"
BACKGROUND_DIR="$STAGE_DIR/.background"
BACKGROUND_IMAGE="$BACKGROUND_DIR/dmg-background.png"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
VERSION="$(
  awk -F ' = |;' '/MARKETING_VERSION = / { print $2; exit }' "$ROOT_DIR/$PROJECT_NAME/project.pbxproj"
)"
DMG_NAME="$APP_NAME-$VERSION.dmg"
ZIP_NAME="$APP_NAME-$VERSION.zip"
VOLUME_NAME="$APP_NAME"

require_xcode() {
  if /usr/bin/xcodebuild -version >/dev/null 2>&1; then
    return
  fi

  if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  fi

  /usr/bin/xcodebuild -version >/dev/null 2>&1
}

clean_output() {
  rm -rf "$DIST_DIR"
  mkdir -p "$DIST_DIR" "$STAGE_DIR" "$BACKGROUND_DIR"
}

sanitize_resource_attributes() {
  /usr/bin/xattr -cr "$ROOT_DIR/icons" >/dev/null 2>&1 || true
  /usr/bin/xattr -cr "$DERIVED_DATA_PATH" >/dev/null 2>&1 || true
}

build_release() {
  /usr/bin/xcodebuild \
    -project "$ROOT_DIR/$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
}

stage_app() {
  if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "Missing built app bundle: $APP_BUNDLE" >&2
    exit 1
  fi

  /usr/bin/swift "$ROOT_DIR/script/create_dmg_background.swift" "$BACKGROUND_IMAGE"
  /usr/bin/rsync -a "$APP_BUNDLE" "$DIST_DIR/"
  /usr/bin/rsync -a "$APP_BUNDLE" "$STAGE_DIR/"
  ln -s /Applications "$STAGE_DIR/Applications"
}

create_zip() {
  (
    cd "$DIST_DIR"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$ZIP_NAME"
  )
}

create_dmg() {
  local rw_dmg="$DIST_DIR/$APP_NAME-$VERSION-rw.dmg"
  local mounted=false
  local mount_dir="$DIST_DIR/$VOLUME_NAME"

  cleanup_dmg_mount() {
    if [[ "$mounted" == true ]]; then
      /usr/bin/hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
    fi
  }
  trap cleanup_dmg_mount EXIT

  rm -f "$rw_dmg" "$DIST_DIR/$DMG_NAME"
  rm -rf "$mount_dir"
  mkdir -p "$mount_dir"

  /usr/bin/hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDRW \
    "$rw_dmg"

  /usr/bin/hdiutil attach \
    "$rw_dmg" \
    -readwrite \
    -noverify \
    -noautoopen \
    -mountpoint "$mount_dir"
  mounted=true

  /usr/bin/SetFile -a V "$mount_dir/.background" >/dev/null 2>&1 || true

  /usr/bin/osascript <<EOF
set mountPath to "$mount_dir"
set backgroundPath to "$mount_dir/.background/dmg-background.png"
tell application "Finder"
  set dmgFolder to POSIX file mountPath as alias
  set backgroundFile to POSIX file backgroundPath as alias
  open dmgFolder
  delay 1
  set containerWindow to container window of dmgFolder
  set current view of containerWindow to icon view
  set toolbar visible of containerWindow to false
  set statusbar visible of containerWindow to false
  set the bounds of containerWindow to {120, 120, 1020, 680}
  set viewOptions to the icon view options of containerWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 160
  set background picture of viewOptions to backgroundFile
  set position of item "$APP_NAME.app" of dmgFolder to {250, 230}
  set position of item "Applications" of dmgFolder to {650, 230}
  update dmgFolder without registering applications
  delay 1
  close containerWindow
end tell
EOF

  /bin/sync
  if [[ "$mounted" == true ]]; then
    /usr/bin/hdiutil detach "$mount_dir"
    mounted=false
  fi

  /usr/bin/hdiutil convert \
    "$rw_dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DIST_DIR/$DMG_NAME"

  rm -f "$rw_dmg"
  rm -rf "$mount_dir"
  trap - EXIT
}

summarize() {
  cat <<EOF
Release artifacts created:
  $DIST_DIR/$APP_NAME.app
  $DIST_DIR/$ZIP_NAME
  $DIST_DIR/$DMG_NAME

Note:
  This build is unsigned. For public distribution without Gatekeeper warnings,
  sign the app with Developer ID Application and notarize the final artifact.
EOF
}

require_xcode
sanitize_resource_attributes
clean_output
build_release
sanitize_resource_attributes
stage_app
create_zip
create_dmg
summarize
