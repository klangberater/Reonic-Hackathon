# Lumen — 5-minute presentation

Slide-by-slide with talk track. **ON SLIDE** = what's projected (sparse). **SAY** = what you say. Sources for every claim: [`competitive-research.md`](competitive-research.md). Exact demo numbers: [`video-script.md`](video-script.md) + the runsheet in `Presentation Notes.md`.

**Time budget (~5:00):** hook 15s · problem 25s · competition 70s · jobs-to-be-done 60s · demo 120s · technical 60s · close 20s.

---

## 1 · Title (0:00–0:15)
**ON SLIDE:** "Lumen — your home energy, handled." · the one screen.
**SAY:** "This is Lumen. Your home makes and uses energy all day — solar, a battery, a heat pump, a car. Today *you* have to make sense of it. We think the home should just tell you what to do."

## 2 · The problem (0:15–0:40)
**ON SLIDE:** a home with solar, battery, heat pump, EV, dynamic tariff, a contract PDF — scattered across 4 apps.
**SAY:** "A modern home has solar, a battery, a heat pump, an EV, a dynamic tariff, and a contract nobody reads — spread across four apps and a PDF. Two things follow: people don't know how to act on it, and they give up trying."

## 3 · The competition: two camps (0:40–1:25)
**ON SLIDE:** two columns — *Silent automators* (Enpal, Tibber, Octopus, 1KOMMA5°) | *Dashboards* (SolarEdge, Fronius, SMA) — and an empty third seat: *Assistant*.
**SAY:** "We looked at everyone. They fall into two camps. One **automates silently** — Enpal, Tibber, Octopus will charge your car at 3am and never tell you why. The other hands you a **dashboard** and makes you the analyst — SolarEdge, SMA, Fronius. Both are real, good products. But look at the empty seat: nobody **forecasts, explains, and advises in plain language.** Nobody is an *assistant*."

## 4 · The honest scorecard (1:25–1:55)
**ON SLIDE:** the feature-gap table (from `competitive-research.md`).
**SAY:** "Here's the honest scorecard — and I'll be fair: some do forward prices, SolarEdge does real fault alerts. Credit where it's due. But the last two columns are empty for *everyone*: a conversational assistant, and actually telling you what to do. That's the seat we take."
*(Honesty: don't say 'nobody forecasts / detects faults' — see guardrails. Frame the gap as the plain-language assistant layer.)*

## 5 · Jobs to be done (1:55–2:55)
**ON SLIDE:** four jobs ranked by frequency —
1. **Run my day on my own power** — *daily* ← most frequent
2. Is it still working? — weekly, fades fast
3. Is something broken? — rare, expensive
4. Right tariff / contract? — yearly
**SAY:** "Why is that seat empty? Because everyone optimised for the wrong job. A solar homeowner has four jobs. The top one — **every single day** — is *'when do I run things to use my own sunshine?'* Then occasionally, *'is it still working?'* Rarely but expensively, *'is something broken?'* And once a year, *'am I on the right tariff?'* Dashboards serve job two — monitoring — and here's the killer: engagement in those apps **drops sixty percent in the first month.** People don't want to watch charts. They want the *daily* job done."

## 6 · So the daily job IS the home screen (2:55–3:10)
**ON SLIDE:** the Lumen home screen.
**SAY:** "So we built the app around the daily job. The home screen isn't a dashboard — it's *'tell me your day, I'll plan it around your sun.'* The rarer jobs surface themselves, only when they matter. Let me show you."

## 7 · Demo (3:10–5:10 — run ~2:00 live)
*Switch to the live app (Sunny demo / Live clock). Follow the runsheet; exact numbers in `video-script.md`.*
- **Voice plan:** "Charge the car by tomorrow morning, and run a load of washing" → spoken *"Planned for the day — €2.72 instead of €13.20, 69% on your own power."* Show the timetable (free midday solar, car across the peak). **Let the spoken reply land.**
- **The plan:** agenda rail, source traffic light (green = your own power), one nudge.
- **The twist (job 3 surfaces itself):** tap the red **"Attention"** chip → the assistant leads with the facts: *"Solar ~55% below normal — 21 vs ~48 kWh/day, 4 days — likely dirt or shading."* It caught *why* today wasn't all-solar.
- *Backup:* type the command if the mic is fussy — the reply still speaks.

## 8 · Technical: how the anomaly works (5:10–5:40)
**ON SLIDE:** "Weather-normalised against your *own* home."
**SAY:** "Two things under the hood. First, that fault — it's not a hardcoded threshold. For every day in your home's own history we learn what the panels, or the heat pump, *should* do at that outdoor temperature, then flag a sustained run that breaks the pattern. That's how it tells a cloudy day from dirty panels, and 'it's just cold out' from a failing heat pump."

## 9 · Technical: the LLM, used safely (5:40–6:10)
**ON SLIDE:** the architecture frame (`architecture-portrait.png`).
**SAY:** "Second — how we use the model safely. One rule: **tools do the math, the model does the words.** The phone only talks to our TypeScript server. When you speak, GPT-4o turns your sentence into *structured tasks* — it never sees or invents a number. Our server prices and schedules everything, and the anomaly evidence is itself a tool the model calls. The model explains; the numbers are always ours. That's why the euros are correct and repeatable."

## 10 · Close (6:10–6:30)
**ON SLIDE:** "Not another dashboard. An assistant."
**SAY:** "Dynamic tariffs just became mandatory in Germany — and half the country doesn't know they exist. Soiling quietly costs five percent a year; one in three heat pumps underperform. Every home is about to need someone to make sense of this. Not another dashboard. An assistant. That's Lumen."

---

## Claims you can defend (keep open in Q&A)
- Two-camps framing, gap table, and the "53% don't know dynamic tariffs," "60% engagement drop in a month," "~5% soiling," "1-in-3 heat pumps" stats → all sourced in [`competitive-research.md`](competitive-research.md).
- **Guardrails (don't overclaim):** SolarEdge *does* detect faults; SMA/Fronius *do* forecast; SMA *does* give basic advice. Our edge is the **plain-language, conversational, on-demand assistant** that ties it together — not "they show nothing."

## Note on timing
The deck adds ~30s vs. a hard 5:00 if the demo runs the full 2:00. If you're tight: cut slide 2 (fold the problem into slide 1) and keep the demo to 1:45. The demo and the two-camps slide are the load-bearing moments — protect those.
