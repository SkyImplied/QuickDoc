#!/usr/bin/env bash
# Build the local Debug test app with ad-hoc signatures and the entitlements
# already stored in the project. This is not a Developer ID signature and it
# is not notarized. It does not install, launch, quit, register, or unregister
# anything, and it does not restart Finder.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="QuickDoc.xcodeproj"
SCHEME_NAME="QuickDoc"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="$ROOT_DIR/build/sidebar-preview/DerivedData"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/QuickDoc.app"
LOGIN_ITEM="$APP_BUNDLE/Contents/Library/LoginItems/QuickDocLoginItem.app"
FINDER_SYNC="$APP_BUNDLE/Contents/PlugIns/QuickDocFinderSync.appex"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

/usr/bin/xcodebuild \
  -project "$ROOT_DIR/$PROJECT_NAME" \
  -scheme "$SCHEME_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  clean build

sign_inside_out() {
  # Login item and Finder Sync are nested bundles. Sign them before the host
  # so the outer signature seals their finished signatures. Do not use --deep.
  /usr/bin/codesign --force --sign - \
    --identifier "com.skyimplied.QuickDoc.LoginItem" \
    --entitlements "$ROOT_DIR/QuickDocLoginItem/QuickDocLoginItem.entitlements" \
    --options runtime \
    "$LOGIN_ITEM"

  /usr/bin/codesign --force --sign - \
    --identifier "com.skyimplied.QuickDoc.FinderSync" \
    --entitlements "$ROOT_DIR/QuickDocFinderSync/QuickDocFinderSync.entitlements" \
    "$FINDER_SYNC"

  /usr/bin/codesign --force --sign - \
    --identifier "com.skyimplied.QuickDoc" \
    --entitlements "$ROOT_DIR/QuickDoc/QuickDoc.entitlements" \
    --options runtime \
    "$APP_BUNDLE"
}

/usr/bin/xattr -cr "$APP_BUNDLE" >/dev/null 2>&1 || true
sign_inside_out
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

python3 - "$APP_BUNDLE" "$LOGIN_ITEM" "$FINDER_SYNC" <<'PY'
import plistlib, subprocess, sys
app, login, appex = sys.argv[1:]

def signature(path):
    detail = subprocess.run(["/usr/bin/codesign", "-dv", path], text=True, capture_output=True)
    text = detail.stderr + detail.stdout
    fields = {}
    for line in text.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            fields[key] = value
    return text, fields

def entitlements(path):
    result = subprocess.run(
        ["/usr/bin/codesign", "-d", "--entitlements", ":-", path],
        text=True, capture_output=True)
    payload = result.stdout.strip()
    if not payload:
        raise SystemExit(f"missing entitlements: {path}\n{result.stderr}")
    return plistlib.loads(payload.encode())

def require(condition, message):
    if not condition:
        raise SystemExit(message)

for path, identifier in (
    (login, "com.skyimplied.QuickDoc.LoginItem"),
    (appex, "com.skyimplied.QuickDoc.FinderSync"),
    (app, "com.skyimplied.QuickDoc"),
):
    text, fields = signature(path)
    require(fields.get("Identifier") == identifier, f"{path} identifier {fields.get('Identifier')}")
    require(fields.get("Signature") == "adhoc", f"{path} is not ad-hoc\n{text}")
    require("Info.plist entries=" in text, f"{path} Info.plist is not sealed\n{text}")
    require("linker-signed" not in text, f"{path} is only linker-signed\n{text}")
    require("Developer ID" not in text and "Authority=" not in text, f"{path} is not a local ad-hoc signature\n{text}")

login_ent = entitlements(login)
app_ent = entitlements(app)
appex_ent = entitlements(appex)
require(login_ent.get("com.apple.security.app-sandbox") is True, "login item sandbox missing")
require(app_ent.get("com.apple.security.automation.apple-events") is True, "app apple-events missing")
require(set(app_ent) == {"com.apple.security.automation.apple-events"}, f"app entitlements changed: {sorted(app_ent)}")
require(appex_ent.get("com.apple.security.app-sandbox") is True, "extension sandbox missing")
require(appex_ent.get("com.apple.security.automation.apple-events") is True, "extension apple-events missing")
require(appex_ent.get("com.apple.security.files.user-selected.read-write") is True, "extension user-selected files missing")
require(appex_ent.get("com.apple.security.temporary-exception.apple-events") == ["com.apple.finder"], "extension Finder AppleEvent exception missing")
require(
    appex_ent.get("com.apple.security.temporary-exception.files.absolute-path.read-write") == ["/Users/", "/Volumes/"],
    "extension shared-settings path exception missing",
)
print("entitlements match the project files")
PY

# Xcode's Debug RegisterWithLaunchServices phase runs lsregister -trusted and
# can mark this build's Finder Sync plug-in enabled. Drop only that product
# so the signed package is left unselected. Other apps are not touched.
/usr/bin/pluginkit -r "$FINDER_SYNC" >/dev/null 2>&1 || true

echo "Signed Debug app: $APP_BUNDLE"
