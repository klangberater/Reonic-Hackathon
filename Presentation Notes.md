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
- Even the price-forward apps (Tibber/Octopus) just *show* you the price graph and leave you to time things yourself; **Cheapest mode** consumes those same forward prices and schedules your loads into the cheap hours for you.
- Nothing explained in words.
- No genuinely useful conversational layer.

**Architecture principle — say it out loud (credibility line):** *tools do the math, the model does the words.* The TypeScript **MCP server** owns all arithmetic; the LLM only does language and judgment, calling tools for every number. This is what makes on-stage numbers correct and repeatable instead of the model saying "€0.42" once and "€4.20" on the re-run. It now runs end-to-end through the **voice pipeline** too: ElevenLabs does speech-to-text, GPT-4o parses the sentence into *structured tasks only*, the MCP server plans and prices them, and ElevenLabs speaks back a verdict built straight from the plan's numbers. The model never invents a euro. Call out the MCP server explicitly — it's the architecture-slide moment.

**The differentiator — name it as the differentiator:** Lumen is a **planner, not just an advisor.** Tell it your day → it finds the greenest/cheapest times → you confirm → loads route around each other (sequential planning; confirmed plans don't silently move). Two incumbent-beating details: the **source traffic light** (green = free own-solar/battery, yellow = partial, red = paid grid — it's about energy *source*, so it works on fixed tariffs too) and a **multi-day timetable** with nudge + re-plan. This is the single most differentiating piece versus every incumbent.

---

## Part 2 — Live walkthrough (the three rehearsed moments)

Judges remember moments, not features. The app opens on the **Plan-my-day screen**: a status chip (top-left) — green "All good" or, when something's wrong, a tappable red **"Attention"** — a one-line verdict of what the home is doing right now, a big **voice mic**, and a manual device grid. Hit exactly these three moments:

1. **Plan by voice (the wow).** On the **Sunny demo** clock, tap the mic and say *"charge the car by tomorrow morning, and run a load of washing."* The transcript appears, the money reveal animates in, and **the app speaks it back**: *"Planned for the day — €2.72 instead of €13.20, 69% on your own power."* The timetable puts the washing on free midday solar and the car across the solar peak. This is the headline: you talked to your home and it planned your day around the sun. (Note the **69%**, not 100% — that's deliberate, and moment 3 explains it.)

2. **The plan it made.** Stay on the result. Point out the **agenda rail / timetable** (chronological, multi-day, with day separators), the **source traffic light** on each block, the Cheapest / Greenest / Soonest toggle, and the **nudge** (move a block ±1h → "Reset to best times" re-plans the rest around it). Honest control note: the car/wallbox is genuinely controllable; appliances are "set delay-start / we'll remind you."

3. **The proactive anomaly — and the twist.** The status chip is already a red *"Attention"* (top-left). **Tap it** and the assistant **opens by telling you what's wrong** — no need to know the question: **"Solar is generating ~55% less than these sunny days normally yield (21 kWh/day vs ~48), sustained 4 days… check the panels for dirt/soiling or shading."** It's a **bright day but the panels are under-producing** — then you can ask follow-ups. This is the payoff: the home didn't just plan your day, it caught *why* today wasn't all-solar. Tools produce the evidence; the model produces the words. *(One narration line you can drop in: the same weather-normalised detector also catches a heat-pump fault in winter — two seasons, one engine. No need to show it.)*

---

## Video script

**The read-aloud script is its own file: [`presentation/video-script.md`](presentation/video-script.md)** — bold lines to speak, italic stage cues, top to bottom. Structure: Intro 25s · Demo 60s · Tech 33s ≈ 1:58. The runsheet below is the *data* it's keyed to.

---

## Demo runsheet — the 2-minute take (exact data)

One continuous flow on **one screen, one clock** — no flipping. Set the **Demo clock** to **Sunny demo** (2026-06-20, 11:00) or **Live** (today) once before recording; everything below happens on that screen. Numbers are from the backend (`HH-1001`, "Familie Becker"), verified live. *(Prep: a clean status bar — `xcrun simctl status_bar booted override --time "9:41" --batteryLevel 100`.)*

**Open on:** red **"Attention"** chip (top-left) · verdict **"Running on free solar — sending 4.5 kW to the grid."**
*(Context if asked on-screen: 27.5 °C, solar 4.8 kW — dimmed by soiling — battery 100%, price €0.12/kWh.)*

**Beat 1 — plan by voice (the wow).** Tap the mic — say **only the command**, then stop (the Simulator mic is your Mac mic; narrate *after* you stop): *"Charge the car by tomorrow morning, and run a load of washing."*
- Transcript quote → "Understanding what you said…" → "Laying it under the sun…"
- **Spoken + on-screen reveal:** *"Planned for the day — €2.72 instead of €13.20, 69% on your own power."*
- **Saves €10.48 / 9.8 kg CO₂ today** vs a last-minute run.
- Timetable: **Washing 11:00–12:30** (free · solar, green) · **Car 11:00–14:30** (68% own power, partial, €2.72 grid).
- *If the mic is fussy on a take:* type the same sentence in "or type it here…" — identical result, the reply still speaks.

**Beat 2 — the plan it made.** Brief: the **agenda rail**, the **source traffic light** (green/yellow/red = free/partial/paid), the Cheapest/Greenest/Soonest toggle, the **nudge** ("Reset to best times").

**Beat 3 — the twist (why only 69%?).** Tap the red **"Attention"** chip. The assistant **opens by stating the situation** (deterministic facts, no typing):
- *"Solar is generating ~55% less than these sunny days normally yield (21 kWh/day vs ~48), sustained 4 days. Check the panels for dirt/soiling or shading — book a clean or inspection. Ask me anything about it."*
- Optional: ask one follow-up ("is it soiling or a fault?") — it hits the LLM with this context.
- Close on the line: the soiling is *why* the plan was 69% and not all-solar — **the home caught the fault and explained it.**

*(Optional narration, no screen change: "the same detector catches a heat-pump fault in winter — two seasons, one engine.")*

> **Why 69% and not 98%:** the panels are dirty across the demo window, so the live solar (4.8 kW) is genuinely lower — and the anomaly explains exactly that. To show a pristine "all done on sunshine" voice plan instead, pull the soiling window (`SOIL_START..SOIL_END` in `scripts/transform_dataset.py`) off the demo day and regenerate the data.

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
