# Lumen — iOS app

SwiftUI client for the energy assistant. Talks to the backend at
`https://getfletcher.ai/api` (configurable in `Sources/Config.swift`).

## Run

```bash
brew install xcodegen          # one-time, if not installed
cd ios && xcodegen generate    # produces Lumen.xcodeproj from project.yml
open Lumen.xcodeproj           # then ⌘R
```

- **Simulator:** runs as-is (endpoint is public HTTPS).
- **Real device:** set a Development Team in Signing & Capabilities (target Lumen). No ATS
  exception needed — the API is HTTPS.

Build from CLI:
```bash
xcodebuild -project Lumen.xcodeproj -scheme Lumen \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Structure
- `project.yml` — XcodeGen spec (the project file itself is gitignored)
- `Sources/Config.swift` — API base URL + default household
- `Sources/Models.swift` — Codable mirror of `/state`
- `Sources/APIClient.swift` — async networking
- `Sources/NowViewModel.swift` — `@MainActor` state, summer/winter clock, verdict line
- `Sources/NowView.swift` — the glance screen (verdict hero, power-flow grid, metric tiles)
- `Sources/Theme.swift` — palette

## Status
Vertical slice done: the **glance** renders live from `/state` with a summer/winter toggle.
Next: a Chat tab against `/chat` (streamed, grounded answers) once that endpoint lands.
