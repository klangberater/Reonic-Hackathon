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
- `project.yml` — XcodeGen spec (the `.xcodeproj` itself is gitignored)
- `Sources/LumenApp.swift` — app entry
- `Sources/RootPager.swift` — horizontal paging between Home and Plan-my-day (+ `PagerDots`)
- `Sources/ClockStore.swift` — shared demo clock (live / winter), injected into both screens
- `Sources/HomeView.swift` + `HomeViewModel.swift` — the glance (verdict, devices, money, anomaly card)
- `Sources/PlanDayView.swift` + `PlanDayViewModel.swift` — pick tasks → solar-aware schedule
- `Sources/DayTimeline.swift` — Canvas timeline (solar curve + split-shaded task blocks)
- `Sources/DeviceSheetView.swift` — single-device picker (drag-to-choose window)
- `Sources/FlowDetailView.swift` — live power-flow detail
- `Sources/ChatView.swift` — grounded assistant (`/chat`)
- `Sources/SettingsView.swift` — clock + appearance
- `Sources/Models.swift` — Codable mirrors of the API
- `Sources/APIClient.swift` — async `URLSession` networking
- `Sources/Theme.swift` — semantic light/dark design tokens
- `Sources/NotificationManager.swift` — local reminders

## Status
All three surfaces are live: **Home** (glance), **Plan my day** (schedule), and **Ask
anything** (grounded chat). The clock defaults to live real time; **Winter demo** is a fixed
scenario for the heat-pump anomaly. Architecture: [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).
