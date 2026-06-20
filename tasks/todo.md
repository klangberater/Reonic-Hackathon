# Tasks

## Data transform — make the Enpal dataset coherent + demo-anchored

**Goal:** Turn the illustrative (seasonally-inverted) Enpal dataset into a physically-coherent,
demo-ready dataset anchored to this weekend (2026-06-20/21), with a real Munich heatwave forecast
on the "now" window and a genuinely cold winter case. Raw data stays untouched in
`enpal-track-dataset/`; output goes to `data/`. All via one reproducible script.

### Plan
- [ ] Fetch + save real Munich forecast for Jun 20-21 (heatwave, 21-34°C) — DONE
- [ ] Write `scripts/transform_dataset.py`:
  - [ ] Shift all timestamps 2025 → 2026 (lands data's 06-20/21 on the demo weekend for free)
  - [ ] Regenerate `outdoor_temp_c` as a clean seasonal+diurnal curve (cold Jan, warm Jul), per-city offset
  - [ ] Overlay the REAL Munich forecast on HH-1001's now-window (interp hourly → 15-min)
  - [ ] Recompute `heatpump_kw` from temperature (heavy when cold, ~0 in summer; capped at per-home HP kW; 0 for HH-1004)
  - [ ] Inject winter heat-pump anomaly (~+60%) for HH-1001 in a genuinely cold week (mid-Jan 2026)
  - [ ] Recompute `total_consumption_kw = house_load + heatpump + ev_charging`
  - [ ] Re-run greedy self-consumption battery+grid dispatch → balance holds by construction
  - [ ] Recompute `monthly_bills.json` from new dispatch (cost, feed-in, self-sufficiency)
  - [ ] Realign `insight_events.json` (anomaly → the cold week; cheapest-window; highest-bill month)
  - [ ] Year-shift `dynamic_prices.json`, `contracts.json` (+ update hardcoded dates in contract_terms_text)
- [ ] Validate: energy balance holds every step; seasonality correct; now-window matches forecast; bills reconcile
- [ ] Write `data/README.md` (derived data + how to regenerate)
- [ ] Commit + push

### Decisions locked
- Positioning: building "what the Enpal app should be" (not a 3rd-party layer)
- Fix scope: FULL re-simulation (coherent whole year, balance by construction)
- Now-window temps: REAL Munich forecast (matches what's outside during judging)

## Review

Done — full re-simulation shipped via `scripts/transform_dataset.py`, output in `data/`.
- Seasonality fixed (cold Jan / warm Jul; HP + temp now coherent with PV/price).
- Now-window (2026-06-20/21) overlaid with the real Munich heatwave forecast (21–34 °C).
- Winter heat-pump anomaly injected (HH-1001, 2026-01-12..19, +61%).
- Energy balance holds to ~1e-15 kW across all 4 homes × 35,040 steps.
- Bills recomputed (HH-1001 ≈ €2,700/yr; Jan €667 → June −€12), insights/contracts/prices realigned.
- Two calibration bugs found + fixed during validation: (1) seasonal phase sign error
  (year was still inverted), (2) heat-pump draw ~10× too high (used nameplate peak as average).

**Demo readiness:** data now cleanly supports all three moments — glance (summer now-screen),
decision (midday-cheap dynamic prices), nudge (winter anomaly + bill forecast).

## Backend + server bring-up (done)
- [x] Minimal Node/TS backend: `/health` + real `/state` (get_current_state) over `data/`, summer/winter clock
- [x] Server setup copied from Hallo-Theo (getfletcher.ai): GH Actions deploy, systemd unit, nginx snippets
- [x] Deployed to server: `/opt/reonic/repo`, `reonic-backend.service` on 127.0.0.1:8090
- [x] nginx `/api/` repointed 8002→8090 (+ auth_basic off), backed up; `/ws` & whatsapp left on theo
- [x] **Verified public HTTPS end-to-end:** `https://getfletcher.ai/api/health` 200, `/api/state` serves live data
- [x] Add `DEPLOY_SSH_KEY` secret → dedicated deploy key authorized for github-runner; push-to-main auto-deploy verified green
- [ ] Add a token guard on `/chat` before exposing (it will call Claude = costs money; `/api/` is public)
- [ ] Retire theo services once ours is fully confirmed (keep as fallback for now)

## iOS app (vertical slice done)
- [x] XcodeGen SwiftUI project (`ios/`), builds for simulator (Xcode 26.5)
- [x] Glance screen (NowView) renders live `/state`: verdict hero, power-flow grid, metric tiles
- [x] Summer/winter clock toggle (re-fetches; summer verified on sim, winter path verified via API)
- [x] Points at `https://getfletcher.ai/api` — runs on sim as-is; real device needs a signing team
- [ ] Chat tab against `/chat` (streamed grounded answers) — after that endpoint lands
- [ ] Verdict line currently templated client-side → swap to LLM-generated when /chat exists

## Building the planner (homescreen-and-backend.md spec)
Order: backend differentiator first → iOS home/device-sheet UI → /chat → TestFlight.

### Backend (DONE, deployed)
- [x] Extend data layer: prices/contracts/bills/insights + ordered records + now-index
- [x] Device library (dishwasher, washing machine, EV) + in-memory commitments ledger
- [x] `optimizeLoad.ts` engine: greenest window, source (free/partial/paid), own-share %, grid cost, ribbon, rationale; sequential route-around via the ledger
- [x] Endpoints: GET /now(+/state), /household, /money, /devices, /optimize_load, /insights; POST /commit_load, GET /commitments, POST /reset
- [x] Verified on real data (summer free / winter route-around / winter health alert); live over HTTPS

### iOS (DONE — verified on simulator via Maestro)
- [x] Home screen: health indicator (quiet/loud), verdict (→ flow detail), money forecast, device tiles, proactive cards, ask bar
- [x] Device sheet: optimize_load → best time, source ribbon (window outlined), share/cost, rationale, control honesty
- [x] Tap → Schedule it → commit_load → tile shows "scheduled · free"; FlowDetail on verdict tap
- [ ] Ask bar is currently a visual placeholder (wires to /chat later)

### Later
- [x] POST /chat: **OpenAI** function-calling over the planner tools (event is OpenAI-sponsored).
  Live + grounded: dishwasher-now, earn-€15, winter why-high-bill. iOS ask bar → chat sheet.
  NOTE: chat UI was added AFTER the first TestFlight archive → re-archive to get chat on the phone.
- [ ] Summer insight set + date-aware insights
- [x] TestFlight: Team ID wired, icon added, ITSAppUsesNonExemptEncryption=NO; build live on the phone
  - ASC listing name "Lumen Energy" (on-device name stays "Lumen"); re-archive+upload for new builds
