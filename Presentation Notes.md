# Presentation Notes — 2-Minute Demo

Working name: **Lumen** · Enpal track · iOS app + TypeScript MCP backend + synthetic household data.

Demo requirements: (1) detailed explanation of the solution, (2) live walkthrough of key features. Target runtime ~2:00.

---

## The one line everything hangs on

Lead with this — it's the whole thesis:

> Every energy app today shows you data and quietly makes *you* the analyst. Lumen does the analysis and just tells you what to do.

Say it plainly: **the assistant is the product** — not a dashboard with a chatbot bolted on. A single calm "now" screen is its face.

---

## Part 1 — Explaining the solution (must mention)

**The problem.** Incumbent apps (Enpal, Tibber, Octopus, SolarEdge) are descriptive and retrospective — a flow diagram and a savings counter. They show what happened, never what to *do* or what's *coming*. People already pay for third-party apps just to make sense of their own energy data; that gap is the product.

**The positioning (for an Enpal room).** Lumen is the layer that sits *on top of* the Enpal app and finally explains it — not a replacement. It mirrors how the market already behaves and is a friendlier message to the host.

**The four incumbent gaps we close** — each tied to a real complaint, which is what makes the pitch defensible:
- No bill forecast (only earnings-to-date).
- No forward price/tariff timeline — the thing Tibber/Octopus users love most.
- Nothing explained in words.
- No genuinely useful conversational layer.

**Architecture principle — say it out loud (credibility line):** *tools do the math, the model does the words.* The TypeScript MCP server owns all arithmetic; Claude only does language and judgment, calling tools for every number. This is what makes on-stage numbers correct and repeatable, instead of the LLM saying "€0.42" once and "€4.20" on the re-run. Call out the MCP server explicitly — it's the architecture-slide moment.

**The differentiator — name it as the differentiator:** Lumen is a **planner, not just an advisor.** Tap a device → it finds the greenest time → you confirm → the load joins a committed-loads ledger → the *next* device routes around it (sequential planning; confirmed plans never silently move). This is the single most differentiating piece versus every incumbent.

---

## Part 2 — Live walkthrough (the three rehearsed moments)

Judges remember moments, not features. Hit exactly these three:

1. **The glance.** Open to one plain sentence, not a wall of gauges — *"Right now you're making more than you're using — battery's charging and you're sending 1.2 kW to the grid."* Show the calm home screen: status dot, verdict line, one forward money number ("On track for €96 this month"), device tiles, and the persistent "Ask anything…" bar in the thumb zone.

2. **The decision.** Type a real homeowner question — *"should I run the dishwasher now or at 3pm?"* → a specific, numeric, actionable answer with savings quantified. Then show the tap → best-time → confirm → plan loop and the **source traffic light**: green = free (your solar/battery), yellow = partial, red = paid grid. It's about energy *source*, not price, so it works on fixed tariffs too.

3. **The proactive nudge.** Something surfaced *unprompted* — anomaly + forecast + savings. E.g. heat pump used more this week, here's the bill impact, still on track and €X under a standard tariff. Show the health indicator going from quiet green to the loudest card on screen.

---

## Cross-cutting must-mentions

- **Synthetic data is fine and intended** — a "virtual now" anchor over a historical 2025 week. Nobody expects live hardware; they expect the *experience* to feel real.
- **Money is quantified everywhere** — specific euros, not vibes. That's how we beat ten prettier dashboards.
- **Control honesty** — the car/wallbox is genuinely controllable (confirm = real automation); appliances are "set delay-start / we'll remind you." Saying which is a credibility detail judges notice.
- **Stay calm and single-screen** — resist showing every tab. Out-simplicity; don't try to out-reliability them in a 2-minute cut.

---

## The judge-facing story (if a slide is shown)

1. Here's the homeowner's reality: solar, battery, heat pump, EV, dynamic tariff, a contract nobody reads — scattered across apps and PDFs.
2. Here's the incumbent's actual app: a flow diagram and a savings counter. Descriptive, retrospective, no answers.
3. Here are the four things it doesn't do — each backed by a real incumbent complaint.
4. Here's Lumen doing all four — live, in three questions a real homeowner would ask.

---

## Reference

- On calm, uncluttered UI (supports the single-screen design principle): <https://www.fastcompany.com/90144106/stop-cluttering-up-your-website-study-suggests-its-bad-for-business>

