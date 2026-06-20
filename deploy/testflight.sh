#!/usr/bin/env bash
# Archive + upload Lumen to TestFlight using an App Store Connect API key.
# Prereqs (one-time): App Store Connect app record for ai.getfletcher.lumen, and an
# App Store Connect API key (App Manager). Set these env vars before running:
#   ASC_KEY_ID      — the key's Key ID
#   ASC_ISSUER_ID   — the API key issuer ID
#   ASC_KEY_PATH    — path to the AuthKey_<KEYID>.p8 file
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?set ASC_KEY_ID}"; : "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"; : "${ASC_KEY_PATH:?set ASC_KEY_PATH}"
AUTH=(-allowProvisioningUpdates
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID"
      -authenticationKeyPath "$ASC_KEY_PATH")

cd ios
xcodegen generate

echo "── archiving (Release, generic iOS) ──"
xcodebuild -project Lumen.xcodeproj -scheme Lumen -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Lumen.xcarchive \
  "${AUTH[@]}" archive

echo "── exporting .ipa ──"
xcodebuild -exportArchive -archivePath build/Lumen.xcarchive \
  -exportPath build/export -exportOptionsPlist ../deploy/ExportOptions.plist \
  "${AUTH[@]}"

echo "── uploading to App Store Connect / TestFlight ──"
xcrun altool --upload-app -f build/export/Lumen.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "✓ uploaded. It will appear in TestFlight after Apple finishes processing (~5–15 min)."
