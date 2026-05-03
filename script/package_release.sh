#!/usr/bin/env bash
set -euo pipefail

APP_NAME="QuickDoc"
SCHEME_NAME="QuickDoc"
PROJECT_NAME="QuickDoc.xcodeproj"
CONFIGURATION="Release"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/dmg-root"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/QuickDoc/Info.plist" \
    | sed 's/$(MARKETING_VERSION)/1.0/'
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
  mkdir -p "$DIST_DIR" "$STAGE_DIR"
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
  /usr/bin/hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME"
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
clean_output
build_release
stage_app
create_zip
create_dmg
summarize
