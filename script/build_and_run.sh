#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="QuickDoc"
EXTENSION_NAME="QuickDocFinderSync"
BUNDLE_ID="com.skyimplied.QuickDoc"
EXTENSION_BUNDLE_ID="$BUNDLE_ID.FinderSync"
PROJECT_NAME="QuickDoc.xcodeproj"
SCHEME_NAME="QuickDoc"
CONFIGURATION="Debug"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
BUILD_ROOT="$ROOT_DIR/build"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
PRODUCTS_DIR="$BUILD_ROOT/$CONFIGURATION"
APP_BUNDLE="$PRODUCTS_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
APP_EXTENSION="$APP_BUNDLE/Contents/PlugIns/$EXTENSION_NAME.appex"

require_xcode() {
  if /usr/bin/xcodebuild -version >/dev/null 2>&1; then
    return
  fi

  if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  fi

  if ! /usr/bin/xcodebuild -version >/dev/null 2>&1; then
    cat >&2 <<'EOF'
Full Xcode is required to build this Finder Sync extension.

If Xcode is already installed, accept its license and select it:
  sudo xcodebuild -license
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
EOF
    exit 1
  fi
}

build_app() {
  require_xcode
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  pkill -x "$EXTENSION_NAME" >/dev/null 2>&1 || true
  mkdir -p "$BUILD_ROOT"

  /usr/bin/xcodebuild \
    -project "$ROOT_DIR/$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    SYMROOT="$BUILD_ROOT" \
    OBJROOT="$BUILD_ROOT/Intermediates" \
    DSTROOT="$BUILD_ROOT/Install" \
    SHARED_PRECOMPS_DIR="$BUILD_ROOT/PrecompiledHeaders" \
    CONFIGURATION_BUILD_DIR="$PRODUCTS_DIR" \
    build
}

clean_build_products() {
  rm -rf "$BUILD_ROOT"
}

refresh_extension_registration() {
  if [[ ! -d "$APP_EXTENSION" ]]; then
    echo "Missing Finder Sync extension: $APP_EXTENSION" >&2
    exit 1
  fi

  "$LSREGISTER" -f -R -trusted "$APP_BUNDLE" >/dev/null 2>&1 || true

  /usr/bin/pluginkit -r "$APP_EXTENSION" >/dev/null 2>&1 || true
  /usr/bin/pluginkit -a "$APP_EXTENSION" >/dev/null 2>&1 || true
  /usr/bin/pluginkit -e use -i "$EXTENSION_BUNDLE_ID" >/dev/null 2>&1 || true
}

restart_finder() {
  /usr/bin/killall Finder >/dev/null 2>&1 || true
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build|--build)
    build_app
    ;;
  clean|--clean)
    clean_build_products
    ;;
  run|--run)
    build_app
    refresh_extension_registration
    restart_finder
    open_app
    ;;
  debug|--debug)
    build_app
    refresh_extension_registration
    restart_finder
    /usr/bin/lldb -- "$APP_BINARY"
    ;;
  logs|--logs)
    build_app
    refresh_extension_registration
    restart_finder
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\" OR process == \"$EXTENSION_NAME\""
    ;;
  telemetry|--telemetry)
    build_app
    refresh_extension_registration
    restart_finder
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  verify|--verify)
    build_app
    refresh_extension_registration
    restart_finder
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    /usr/bin/pluginkit -m -i "$EXTENSION_BUNDLE_ID" || true
    ;;
  *)
    echo "usage: $0 [build|clean|run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
