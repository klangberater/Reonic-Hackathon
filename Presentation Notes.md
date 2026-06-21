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

Judges remember moments, not features. The app opens on the **Plan-my-day screen**: a status chip (top-left) — green "All good" or, when something's wrong, a tappable red **"Attention"** — a one-line verdict of what the home is doing right now, a big **voice mic**, and a manual device grid. Hit exactly these three moments:

1. **Plan by voice (the wow).** On the **Sunny demo** clock, tap the mic and say *"charge the car by tomorrow morning, and run a load of washing."* The transcript appears, the money reveal animates in, and **the app speaks it back**: *"Planned for the day — €2.72 instead of €13.20, 69% on your own power."* The timetable puts the washing on free midday solar and the car across the solar peak. This is the headline: you talked to your home and it planned your day around the sun. (Note the **69%**, not 100% — that's deliberate, and moment 3 explains it.)

2. **The plan it made.** Stay on the result. Point out the **agenda rail / timetable** (chronological, multi-day, with day separators), the **source traffic light** on each block, the Cheapest / Greenest / Soonest toggle, and the **nudge** (move a block ±1h → "Reset to best times" re-plans the rest around it). Honest control note: the car/wallbox is genuinely controllable; appliances are "set delay-start / we'll remind you."

3. **The proactive anomaly — and the twist.** The status chip is already a red *"Attention"* (top-left). **Tap it** and the assistant explains the 69%: **"Solar output ~55% below normal — generating ~55% less than these sunny days normally yield (21 kWh/day vs ~48), sustained 4 days."** It's a **bright day but the panels are under-producing** — likely **soiling/dirt or shading** — and it suggests a panel clean. This is the payoff: the home didn't just plan your day, it caught *why* today wasn't all-solar. Same engine works in winter — flip to **Winter demo** and the same red chip explains the **heat pump at ~64% over** (defrost fault / low refrigerant / thermostat). One weather-normalised detector, two seasons, two faults. Tools produce the evidence; the model produces the words.

---

## Demo runsheet — exact data (rehearse against these)

Nothing to generate: the sunny day, the solar-soiling run, and the heat-pump anomaly are all seeded in the synthetic dataset and detected live. You only set the **Demo clock** (Settings → Demo clock). Numbers below are from the backend (`HH-1001`, "Familie Becker"). The **demo day is the summer day** — voice plan and the solar anomaly happen on the *same* screen and tell one story.

### Scenario A — Voice plan + solar anomaly (the demo day) · clock = **Sunny demo** (2026-06-20, 11:00) or **Live** (today)

**On open you'll see:** status chip is red **"Attention"** · verdict **"Running on free solar — sending 4.5 kW to the grid."**
*(Context: 27.5 °C, solar 4.8 kW — dimmed by soiling — battery 100%, exporting 4.5 kW, price €0.12/kWh.)*

**Step 1 — plan by voice.** Tap the mic (or type in "or type it here…"): *"Charge the car by tomorrow morning, and run a load of washing."*
- Transcript quote → "Understanding what you said…" → "Laying it under the sun…"
- **Spoken + on-screen reveal:** *"Planned for the day — €2.72 instead of €13.20, 69% on your own power."*
- **Saves €10.48 / 9.8 kg CO₂ today** vs a last-minute run.
- Timetable: **Washing 11:00–12:30** (free · solar, green) · **Car 11:00–14:30** (68% own power, partial, €2.72 grid).
- *Backup if mic/network is flaky:* type the same sentence — identical result, no audio dependency.

**Step 2 — the twist (why only 69%?).** The top status chip is a red **"Attention"** (with a chevron). **Tap it → the assistant explains** (seeded with "Why is my solar generating less than it should?"):
- *"Solar output ~55% below normal — generating ~55% less than these sunny days normally yield (21 kWh/day vs ~48), sustained 4 days."* (detected run 16–19 Jun)
- Names **soiling/dirt, shading, or a string/inverter fault**, and suggests a panel clean — leading with the numbers.

The soiling is *why* the voice plan landed at 69% and not all-solar: one connected story.

### Scenario B — Same detector, another season · clock = **Winter demo** (2026-01-15, 08:00)

Flip the clock to prove the anomaly engine generalises. Status stays red **"Attention"** · verdict **"Pulling 3.1 kW from the grid right now."**
*(Context: −1.2 °C, heat pump drawing 2.5 kW, battery 0%, importing 3.1 kW, price €0.48/kWh; month cost-to-date €320, projected €692.)*

**Tap the red "Attention" chip → the assistant explains:** **"Heat pump using ~64% more than usual"** — *"…64% above what these temperatures normally need (2.2 kW vs ~1.4 kW), sustained 3 days… possible defrost fault, low refrigerant, or thermostat misconfiguration… other loads are normal, so it's isolated to the heat pump."* (run 12–14 Jan)

Two seasons, two faults, **one weather-normalised detector** — tools produce the evidence, the model produces the words.

> **Why 69% and not 98%:** the panels are dirty across the demo window, so the live solar (4.8 kW) is genuinely lower and the plan can't be all-solar — and the anomaly card explains exactly that. If you'd rather show a pristine "all done on sunshine" voice plan, the soiling window (`SOIL_START..SOIL_END` in `scripts/transform_dataset.py`) can be pulled back off the demo day and the data regenerated.

---

## Cross-cutting must-mentions

- **Synthetic data is fine and intended** — a full-2026 dataset at 15-min resolution with a "virtual now" anchor. Nobody expects live hardware; they expect the *experience* to feel real.
- **Money is quantified everywhere** — specific euros, not vibes (€2.72 vs €13.20, saves €10.48). That's how we beat ten prettier dashboards.
- **The voice loop is real, end-to-end** — real STT, real GPT-4o parsing into structured tasks, real planner, real TTS. No stubs. But the *numbers* come from tools, not the model.
- **Control honesty** — the car/wallbox is genuinely controllable (confirm = real automation); appliances are "set delay-start / we'll remind you." Saying which is a credibility detail judges notice.
- **Stay calm and single-screen** — one screen, talk to it, done. Out-simplicity; don't try to out-reliability them in a 2-minute cut.

---

## The judge-facing story (if a slide is shown)

1. Here's the homeowner's reality: solar, battery, heat pump, EV, dynamic tariff, a contract nobody reads — scattered across apps and PDFs.
2. Here's the incumbent's actual app: a flow diagram and a savings counter. Descriptive, retrospective, no answers.
3. Here are the four things it doesn't do — each backed by a real incumbent complaint.
4. Here's Lumen doing it — you *speak* your day and it plans it around the sun, and it catches dirty, under-producing panels (and, in winter, a failing heat pump) before the bill does.

---

## Reference

- On calm, uncluttered UI (supports the single-screen design principle): <https://www.fastcompany.com/90144106/stop-cluttering-up-your-website-study-suggests-its-bad-for-business>
