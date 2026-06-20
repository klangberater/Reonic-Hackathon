# Project Brief — The Energy Assistant That Explains Your House

**Hackathon track:** Enpal — turn a household's messy energy reality into one clear, actionable view.
**Working name:** Lumen (placeholder — swap freely)
**Team:** Full-stack JS/TS · **Time:** 1–2 days · **Scope philosophy:** one compelling experience, done deep.

---

## 1. The one-sentence pitch

> Every energy app today shows you data and quietly makes *you* the analyst. Ours does the analysis and just tells you what to do.

The product is not a dashboard with a chatbot bolted on. **The assistant is the product**, and a single calm "now" screen is its face. Everything the brief asks for — unified view, conversational layer, tariff intelligence, proactive nudges — hangs off one spine: *messy household data → grounded, numeric, plain-language answers.*

---

## 2. Why this wins (the strategic read)

The brief tells us how to win in two lines: *"Depth on one compelling experience beats a shallow version of everything"* and *"doesn't just visualize data."* Translation: every other team builds a pretty dashboard; the judges will have seen ten by the time they reach us. The differentiator is **specific, money-quantified answers**, not vibes.

The opportunity is validated by the market itself: across every incumbent ecosystem there is a cottage industry of *third-party* apps (SolarView for SolarEdge, OctopusWatch / Agile Watcher / Bright for Octopus) whose entire pitch is "proactive, not just passive viewing." People are already paying to bolt comprehension onto apps that only show raw data. As one solar guide put it, for most homeowners the monitoring app is basically a mystery they rarely open and barely understand. That gap is the product.

---

## 3. The three demo moments (build toward exactly these)

Judges remember moments, not features. Nail three:

1. **The glance.** App opens to one sentence, not a wall of gauges: *"Right now you're making more than you're using — battery's charging and you're sending 1.2 kW to the grid."* One simple flow visual underneath. A non-expert gets it in two seconds.
2. **The decision.** User types *"should I run the dishwasher now or at 3pm?"* → *"Wait until 1pm — your solar will cover it and you'll save €0.42 vs. running now at the €0.38/kWh peak."* Specific, numeric, actionable.
3. **The proactive nudge.** *"Your heat pump used 38% more this week than last — that's the cold snap, and it'll add ~€14 to your bill. You're still on track for €87 this month, €23 under a standard tariff."* Anomaly + forecast + savings, unprompted.

These three map precisely onto the incumbent blind spots in §5. Land them and we've covered all four suggested scope items through one coherent experience.

---

## 4. Competitive landscape

### What the incumbents do

| App | Loved for | Hated for |
|---|---|---|
| **Enpal** (host) | Clean live overview; recently reorganized into tabs; heat-pump + wallbox control | Reliability — reviewers say it'd be 5 stars if it stopped freezing |
| **Tibber** | Transparency, hourly prices, **next-day price forecast for planning**, EV smart charging, real savings | App lag/backend flakiness; missing integrations; the in-app **"AI chat is totally useless"** |
| **Octopus (Agile)** | Dynamic/plunge pricing; behavior-shifting done best | Even their own statement is overwhelming ("a lot of rows"); legibility outsourced to 3rd-party apps |
| **SolarEdge / Enphase / Growatt** | Powerful, panel-level data | Confusing; passive; "is today good or bad?" goes unanswered |

### Patterns to steal (users consistently love these)

- **Transparency** — let people see what builds their price; never hide the number behind a happy face.
- **A forward-looking price timeline** — seeing cheap windows *ahead* is what actually changes behavior.
- **Action tied to EV/appliance timing** — the value people cite is always "I shifted my dishwasher / car charge and saved X."

---

## 5. The Enpal app, mapped — and where the white space is

Enpal's app is a **global money status bar + four tabs**:

- **Status bar (every screen):** current credit balance + accumulated earnings (e.g. "€1,512 balance / €1,770 earned since Feb"). Leads with money — good instinct.
- **Tab 1 · Home/Status:** financial summary — earnings from grid feed-in + savings from the Enpal tariff. *Retrospective only.*
- **Tab 2 · Monitoring:** three sub-tabs — **Übersicht** (production vs. consumption, day→year), **Energiesystem** (live flow: solar, battery, feed-in, grid draw), **Verbraucher** (per-device: household, wallbox, heat pump).
- **Tab 3 · Wallbox:** charge level/speed/range; charge modes (fast → cheap); charge history with expense-export.
- **Tab 4 · Wärmepumpe:** live consumption; temperature + schedule settings; "store surplus solar as hot water."

**Everything is descriptive and retrospective.** It shows what happened and what's happening — never what to *do* or what's *coming*. The gaps, each of which one of our demo moments fills:

| Gap in the Enpal app | Our answer |
|---|---|
| No bill forecast (only earnings-to-date) | "On track for €87 this month" |
| **No price/tariff timeline** — the thing Tibber/Octopus users love most | Forward price strip + "run it at 1pm" |
| Nothing explained in words | Plain-language verdicts on every metric |
| No conversational layer at all | The grounded assistant |
| Contract/documents live in a separate web portal | Surface "is this still a good deal?" in-app |

We are not competing with a smart assistant — we're competing with a flow diagram and a savings counter.

> **Pitch framing:** position Lumen as the layer that sits *on top of* the Enpal app and finally explains it — not a replacement. This mirrors how the market already behaves, and it's a friendlier message to a room full of Enpal people.

---

## 6. Design principles (each earned from a real incumbent complaint)

1. **Lead with interpretation, not data.** Every metric gets a verdict: "Today's a strong day — 18% above your usual." This is what AI uniquely unlocks and the spine of the comprehension pitch. *(Incumbents show numbers; none tell you if the number is good.)*
2. **Push the 1–2 things that matter today, unprompted.** The apps wait to be opened; people don't open them. *(Third parties literally sell "proactive monitoring" as the upgrade.)*
3. **A genuinely grounded assistant is the most defensible edge.** A Tibber user calling the in-app AI useless tells us the bar is on the floor.
4. **Make bill explanation + contract intelligence first-class.** "Why was my bill higher?" is a literal top homeowner question, and the app-vs-bill gap actively confuses people.
5. **Out-simplicity, not out-reliability.** We can't beat their stability in a weekend, but a fast, calm, single-screen experience reads as more polished than a feature-stuffed dashboard that freezes. Resist adding a tab per device.

---

## 7. Architecture

**Principle that makes or breaks the demo: tools do the math, the model does the words.** If the LLM free-form reasons about numbers, it *will* say "€0.42" once and "€4.20" on the re-run, live, on stage. Grounding via tools is what makes answers correct and repeatable.

```
[ Synthetic household data ]   ← realistic week, 15-min intervals
        │                        solar, battery SoC, heat pump, EV,
        │                        grid import/export + hourly dynamic tariff + short contract
        ▼
[ MCP server (Node/TS) ]  ← owns ALL arithmetic
   tools:
     get_current_state()
     get_consumption(device, range)
     get_tariff(window)
     forecast_bill()
     simulate_appliance_run(device, start_time)   ← the money tool
        │
        ▼
[ Claude ]  ← language + judgment only; calls tools for every number
        │
        ▼
[ Next.js + Tailwind ]  ← one "now" screen + chat panel
```

- **Synthetic data is expected and fine.** Nobody expects live hardware; they expect the *experience* to feel real, and good data is what sells it.
- **The MCP server is worth doing** — the brief invites it, the judges clearly care, it cleanly separates data+math from language, and it makes a great architecture slide.
- **No auth, settings, multi-home, or device integrations.** Out of scope.

---

## 8. Build plan (1–2 days)

| Window | Work | Why first |
|---|---|---|
| Hrs 0–3 | Synthetic data generator + tariff model | Unblocks everyone |
| Hrs 3–8 | MCP server with the 5 tools, each returning correct numbers; test standalone | The grounding foundation |
| Hrs 8–14 | Wire Claude to tools; get the 3 demo answers reliable | De-risk the demo early |
| Hrs 14–20 | "Now" screen + chat UI; make moment #1 beautiful | The face of the product |
| Remaining | Proactive nudge generation, polish, rehearse the script to muscle memory | Moments win, not features |

---

## 9. Scope guardrails

**In:** one now-screen, chat panel, 5 grounded tools, synthetic week of data, 3 rehearsed demo moments, a "money left on the table" counter if time allows.

**Out:** auth, onboarding, settings, multi-home, real device/inverter integrations, native mobile, historical data beyond the demo week, anything that adds a tab.

---

## 10. The judge-facing story (one slide)

1. Here's the homeowner's reality: solar, battery, heat pump, EV, dynamic tariff, a contract nobody reads — scattered across apps and PDFs.
2. Here's the incumbent's actual app (Enpal's four tabs): a flow diagram and a savings counter. Descriptive, retrospective, no answers.
3. Here are the four things it doesn't do — and every claim is backed by a real complaint from a real incumbent (Tibber's useless chat, SolarEdge's mystery dashboard, Octopus's wall of rows).
4. Here's Lumen doing all four — live, in three questions a real homeowner would ask.

*Defensible because every clause traces to evidence, and the demo proves it in 90 seconds.*
