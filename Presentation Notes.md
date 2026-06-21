# Presentation Notes — 2-Minute Demo

Working name: **Lumen** · Enpal track · iOS app + TypeScript MCP backend + synthetic household data.

Demo requirements: (1) detailed explanation of the solution, (2) live walkthrough of key features. Target runtime ~2:00.

> **What changed since v1:** the app is now a **single Plan-my-day screen** (the old "glance" home is intentionally hidden), and it has a **conversational voice layer** — you speak your day, it plans it, and it talks the answer back. The walkthrough below is built around that. Exact demo numbers are pulled from the live backend and listed in the runsheet at the bottom.

---

## The one line everything hangs on

Lead with this — it's the whole thesis:

> Every energy app today shows you data and quietly makes *you* the analyst. Lumen does the analysis and just tells you what to do.

Say it plainly: **the assistant is the product** — not a dashboard with a chatbot bolted on. One calm screen where you *talk to your home* is its face.

---

## Part 1 — Explaining the solution (must mention)

**The problem.** Incumbent apps (Enpal, Tibber, Octopus, SolarEdge) are descriptive and retrospective — a flow diagram and a savings counter. They show what happened, never what to *do* or what's *coming*. People already pay for third-party apps just to make sense of their own energy data; that gap is the product.

**The positioning (for an Enpal room).** Lumen is the layer that sits *on top of* the Enpal app and finally explains it — not a replacement. It mirrors how the market already behaves and is a friendlier message to the host.

**The four incumbent gaps we close** — each tied to a real complaint, which is what makes the pitch defensible:
- No bill forecast (only earnings-to-date).
- No forward price/tariff timeline — the thing Tibber/Octopus users love most.
- Nothing explained in words.
- No genuinely useful conversational layer.

**Architecture principle — say it out loud (credibility line):** *tools do the math, the model does the words.* The TypeScript **MCP server** owns all arithmetic; the LLM only does language and judgment, calling tools for every number. This is what makes on-stage numbers correct and repeatable instead of the model saying "€0.42" once and "€4.20" on the re-run. It now runs end-to-end through the **voice pipeline** too: ElevenLabs does speech-to-text, GPT-4o parses the sentence into *structured tasks only*, the MCP server plans and prices them, and ElevenLabs speaks back a verdict built straight from the plan's numbers. The model never invents a euro. Call out the MCP server explicitly — it's the architecture-slide moment.

**The differentiator — name it as the differentiator:** Lumen is a **planner, not just an advisor.** Tell it your day → it finds the greenest/cheapest times → you confirm → loads route around each other (sequential planning; confirmed plans don't silently move). Two incumbent-beating details: the **source traffic light** (green = free own-solar/battery, yellow = partial, red = paid grid — it's about energy *source*, so it works on fixed tariffs too) and a **multi-day timetable** with nudge + re-plan. This is the single most differentiating piece versus every incumbent.

---

## Part 2 — Live walkthrough (the three rehearsed moments)

Judges remember moments, not features. The app opens on the **Plan-my-day screen**: a status chip (top-left), a one-line verdict of what the home is doing right now, a big **voice mic**, a manual device grid, and — when something's wrong — a red "Needs a look" card. Hit exactly these three moments:

1. **Plan by voice (the wow).** On **Sunny demo** clock, tap the mic and say *"charge the car by tomorrow morning, and run a load of washing."* The transcript appears, then the money reveal animates in and **the app speaks it back**: *"All done on sunshine — €0.87 instead of €13.20, 98% on your own power."* The timetable shows the washing on free midday solar and the car charging across the solar peak. This is the headline: you talked to your home and it planned your day around the sun.

2. **The plan it made.** Stay on the result. Point out the **agenda rail / timetable** (chronological, multi-day, with day separators), the **source traffic light** on each block, the Cheapest / Greenest / Soonest toggle, and the **nudge** (move a block ±1h → "Reset to best times" re-plans the rest around it). Honest control note: the car/wallbox is genuinely controllable; appliances are "set delay-start / we'll remind you."

3. **The proactive anomaly.** Switch the clock to **Winter demo** in Settings. The status chip flips from a quiet green *"All good"* to a loud red *"Attention,"* and a **"Needs a look"** card surfaces *unprompted*: **"Heat pump using ~64% more than usual"** — *"~64% above what these temperatures normally need (2.2 kW vs ~1.4 kW), sustained 3 days"* — with the action *"Check heat pump settings / book a service inspection."* This is the credibility beat: the number is **weather-normalised against the home's own history**, so it tells "it's just cold out" apart from "something's actually wrong," and confirms other loads are normal so the fault is isolated to the pump. Tools produce the evidence; the assistant supplies the causal words (defrost fault / low refrigerant / thermostat).

---

## Demo runsheet — exact data (rehearse against these)

Nothing to generate: the sunny day and the heat-pump anomaly are already seeded in the synthetic dataset and detected live. You only set the **Demo clock** (Settings → Demo clock). Numbers below are from the live backend (`HH-1001`, "Familie Becker").

### Scenario A — Sunny voice plan (the wow) · clock = **Sunny demo** (2026-06-20, 11:00)

**On open you'll see:** status chip green **"All good"** · verdict **"Running on free solar — sending 7.7 kW to the grid."**
*(Context if asked: 27.5 °C, solar 8.0 kW, battery 100%, exporting 7.7 kW, price €0.12/kWh.)*

**Say (or type in "or type it here…"):** *"Charge the car by tomorrow morning, and run a load of washing."*

**What appears:**
- Transcript quote, then "Understanding what you said…" → "Laying it under the sun…"
- **Spoken + on-screen reveal:** *"All done on sunshine — €0.87 instead of €13.20, 98% on your own power."*
- **Saves €12.33 / 14 kg CO₂ today** vs a last-minute run.
- Timetable: **Washing 11:00–12:30** (free · solar, green light) · **Car 11:00–14:30** (97% own power, mixed, €0.87 grid).
- Optional: toggle Greenest/Soonest, or nudge a block → "Reset to best times".

**Backup if mic/network is flaky:** type the exact same sentence in the field under the mic — identical result, no audio dependency.

### Scenario B — Proactive anomaly · clock = **Winter demo** (2026-01-15, 08:00)

**On switch you'll see:** status chip flips to red **"Attention"** · verdict **"Pulling 3.1 kW from the grid right now."**
*(Context: −1.2 °C, heat pump drawing 2.5 kW, battery 0%, importing 3.1 kW, price €0.48/kWh; month cost-to-date €320, projected €692.)*

**"Needs a look" card (below Make my plan):**
- Title: **"Heat pump using ~64% more than usual"**
- Detail: *"Heat-pump electricity is ~64% above what these temperatures normally need (2.2 kW vs ~1.4 kW), sustained 3 days."* (period 12–14 Jan)
- Action: *"Check heat pump settings / book a service inspection."*

**The causal narrative (assistant adding words to the tool's numbers):** *"…about 64% higher than expected for these temperatures, sustained three days. Possible defrost fault, low refrigerant, or thermostat misconfiguration… other loads are normal, so it's isolated to the heat pump."*

> **Honesty for the demo:** the on-screen card is the wired moment. The conversational *chat* surface that voices the causal "why" is dialled back in this single-screen cut — it's backend-proven and reachable via the assistant, but don't click a chat button that isn't on screen. Demo the card; *describe* the causal depth.

### Third clock — **Live**
Tracks the real wall clock (pinned to the data year). Great for "this is real-time," but at night there's no solar, so **don't** run the voice-plan wow on it — use Sunny demo for that beat.

---

## Cross-cutting must-mentions

- **Synthetic data is fine and intended** — a full-2026 dataset at 15-min resolution with a "virtual now" anchor. Nobody expects live hardware; they expect the *experience* to feel real.
- **Money is quantified everywhere** — specific euros, not vibes (€0.87 vs €13.20, saves €12.33). That's how we beat ten prettier dashboards.
- **The voice loop is real, end-to-end** — real STT, real GPT-4o parsing into structured tasks, real planner, real TTS. No stubs. But the *numbers* come from tools, not the model.
- **Control honesty** — the car/wallbox is genuinely controllable (confirm = real automation); appliances are "set delay-start / we'll remind you." Saying which is a credibility detail judges notice.
- **Stay calm and single-screen** — one screen, talk to it, done. Out-simplicity; don't try to out-reliability them in a 2-minute cut.

---

## The judge-facing story (if a slide is shown)

1. Here's the homeowner's reality: solar, battery, heat pump, EV, dynamic tariff, a contract nobody reads — scattered across apps and PDFs.
2. Here's the incumbent's actual app: a flow diagram and a savings counter. Descriptive, retrospective, no answers.
3. Here are the four things it doesn't do — each backed by a real incumbent complaint.
4. Here's Lumen doing it — you *speak* your day and it plans it around the sun, and it catches a failing heat pump before the bill does.

---

## Reference

- On calm, uncluttered UI (supports the single-screen design principle): <https://www.fastcompany.com/90144106/stop-cluttering-up-your-website-study-suggests-its-bad-for-business>
