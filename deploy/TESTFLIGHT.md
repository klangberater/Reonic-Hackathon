# Getting Lumen onto your phone via TestFlight

Team ID `B7RGVXV5VT` is wired into `ios/project.yml`. The project builds in Release. What's
missing is Apple-side setup that needs your account. Two paths — pick one.

## Path A — Xcode GUI (fastest first build, no key sharing)
1. `cd ios && xcodegen generate && open Lumen.xcodeproj`
2. Select the **Lumen** target → Signing & Capabilities → confirm team **B7RGVXV5VT**,
   "Automatically manage signing" on. (Xcode creates the distribution cert + profile.)
3. On appstoreconnect.com → **Apps → + → New App**: platform iOS, name **Lumen**,
   bundle id **ai.getfletcher.lumen**, an SKU (e.g. `lumen`), primary language English.
4. In Xcode: choose **Any iOS Device** as the run destination → **Product → Archive**.
5. In the Organizer: **Distribute App → TestFlight & App Store Connect → Upload**.
6. After processing (~5–15 min), open **TestFlight** on your iPhone (signed in with the same
   Apple ID — you're an internal tester automatically) → install Lumen.

## Path B — automated CLI (repeatable; I can run it)
Needs an **App Store Connect API key** so the build can sign + upload headlessly.
1. appstoreconnect.com → **Users and Access → Integrations → App Store Connect API →
   generate key**, role **App Manager**. Download the `AuthKey_XXXX.p8` (one chance!).
   Note the **Key ID** and **Issuer ID**.
2. Create the app record (Path A step 3) — or I can create it via the API with that key.
3. Run:
   ```bash
   export ASC_KEY_ID=XXXX ASC_ISSUER_ID=xxxxxxxx-xxxx-... ASC_KEY_PATH=/path/AuthKey_XXXX.p8
   ./deploy/testflight.sh
   ```
   Archives → exports `.ipa` → uploads to TestFlight.

Notes
- The bundle id `ai.getfletcher.lumen` is registered automatically on first archive (Path A) or
  via the API (Path B).
- If `xcodebuild -exportArchive` rejects `method app-store-connect` on an older toolchain, change
  it to `app-store` in `deploy/ExportOptions.plist`.
- The app talks to `https://getfletcher.ai/api` (public HTTPS) — works on cellular or any Wi-Fi.
