#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="QuickDoc"
EXTENSION_NAME="QuickDocFinderSync"
BUNDLE_ID="com.skyimplied.QuickDoc"
EXTENSION_BUNDLE_ID="$BUNDLE_ID.FinderSync"
OLD_BUNDLE_ID="com.skyimplied.Easyright"
OLD_EXTENSION_BUNDLE_IDS=(
  "$OLD_BUNDLE_ID.FinderSync"
  "$OLD_BUNDLE_ID.FinderExtension"
)
PROJECT_NAME="QuickDoc.xcodeproj"
SCHEME_NAME="QuickDoc"
CONFIGURATION="Debug"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
DERIVED_DATA_PATH="$ROOT_DIR/DerivedData"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
APP_EXTENSION="$APP_BUNDLE/Contents/PlugIns/$EXTENSION_NAME.appex"
OLD_APP_BUNDLES=(
  "$ROOT_DIR/build/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
  "$HOME/Library/Developer/Xcode/DerivedData/Easyright-ekhkuxvymzixztdmqdzizzgmlnfq/Build/Products/Debug/Easyright.app"
  "$HOME/Library/Developer/Xcode/DerivedData/Easyright-biujlxpxstdtflhhaxfwccnfekpw/Build/Products/Debug/Easyright.app"
)

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
  pkill -x "Easyright" >/dev/null 2>&1 || true
  pkill -x "EasyrightFinderSync" >/dev/null 2>&1 || true

  /usr/bin/xcodebuild \
    -project "$ROOT_DIR/$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
}

refresh_extension_registration() {
  if [[ ! -d "$APP_EXTENSION" ]]; then
    echo "Missing Finder Sync extension: $APP_EXTENSION" >&2
    exit 1
  fi

  for old_app_bundle in "${OLD_APP_BUNDLES[@]}"; do
    "$LSREGISTER" -u "$old_app_bundle" >/dev/null 2>&1 || true
  done
  "$LSREGISTER" -f -R -trusted "$APP_BUNDLE" >/dev/null 2>&1 || true

  /usr/bin/pluginkit -r "$APP_EXTENSION" >/dev/null 2>&1 || true
  /usr/bin/pluginkit -a "$APP_EXTENSION" >/dev/null 2>&1 || true
  /usr/bin/pluginkit -e use -i "$EXTENSION_BUNDLE_ID" >/dev/null 2>&1 || true

  for old_bundle_id in "${OLD_EXTENSION_BUNDLE_IDS[@]}"; do
    /usr/bin/pluginkit -e ignore -i "$old_bundle_id" >/dev/null 2>&1 || true
  done
}

restart_finder() {
  /usr/bin/killall Finder >/dev/null 2>&1 || true
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

build_app
refresh_extension_registration
restart_finder

case "$MODE" in
  run|--run)
    open_app
    ;;
  debug|--debug)
    /usr/bin/lldb -- "$APP_BINARY"
    ;;
  logs|--logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\" OR process == \"$EXTENSION_NAME\""
    ;;
  telemetry|--telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  verify|--verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    /usr/bin/pluginkit -m -i "$EXTENSION_BUNDLE_ID" || true
    for old_bundle_id in "${OLD_EXTENSION_BUNDLE_IDS[@]}"; do
      /usr/bin/pluginkit -m -i "$old_bundle_id" || true
    done
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
