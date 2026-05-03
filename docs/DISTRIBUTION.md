# QuickDoc Distribution Notes

## Current release shape

The repository can now produce:

- `dist/QuickDoc.app`
- `dist/QuickDoc-1.0.zip`
- `dist/QuickDoc-1.0.dmg`

Use `./script/package_release.sh` to regenerate them.

## What is ready now

- Release build automation
- DMG packaging for drag-and-drop installation
- ZIP packaging for direct download
- README instructions for end users

## What is still required for a polished public macOS release

For broad public distribution, especially to users who are not comfortable bypassing Gatekeeper once, add:

1. Developer ID Application signing
2. Notarization with Apple
3. Stapling the notarization ticket to the app or DMG

## Current blocker on this machine

`security find-identity -v -p codesigning` currently reports `0 valid identities found`, so this Mac does not yet have a usable Developer ID signing certificate installed.

## Recommended next step when the certificate is ready

After installing a valid Developer ID Application certificate, update the Xcode signing settings away from ad-hoc signing and add a notarization step after `./script/package_release.sh`.
