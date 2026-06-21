# Lumen — 2-minute video script (read aloud)

Read the **bold lines** straight through. *Italics are stage cues — don't read them.* Total ≈ 2:00.

---

### 0:00 · Intro
*(on screen: the app open)*

**Every energy app today shows you a wall of charts — and quietly makes you the analyst. Lumen flips that: it does the analysis, and just tells you what to do.**

**It's an assistant for a home with solar, a battery, a heat pump, an EV. One calm screen you talk to — tell it your day, it plans your energy around your own sunshine, and it catches problems before they hit your bill.**

---

### 0:25 · Demo — plan by voice
*(tap the mic. Say only the command, then STOP and stay silent — let the app's reply play.)*

**"Charge the car by tomorrow morning, and run a load of washing."**

*(the app speaks back — wait for it, don't talk over it:)*
> *"Planned for the day — €2.72 instead of €13.20, 69% on your own power."*

**It understood me, scheduled both around the solar peak, and told me the cost — real euros, not vibes.**

---

### 0:52 · Demo — the plan
*(point at the timeline)*

**Washing on free midday solar, the car across the sunniest hours. Green means free — your own power.**

---

### 1:02 · Demo — the twist
*(tap the red "Attention" chip at the top)*

**But it said sixty-nine percent — not a hundred. Why?**

*(tap → the assistant opens with the facts)*

**It's a bright day, but my panels are generating fifty-five percent below normal — likely dirt or shading. It caught the fault, explained it in plain words — and that's why today couldn't run all-solar.**

---

### 1:25 · Technical
*(cut to the architecture frame — `architecture-portrait.png` or `architecture.png`)*

**Under the hood, one principle: tools do the math, the model does the words. The phone only talks to our TypeScript server — it owns every number, so nothing's hallucinated.**

**The hard part is the fault detection: from your home's own history it learns what your panels should do at each temperature, then flags a sustained break — telling a cloudy day from a failing one.**

**A scheduler routes each load around the ones already committed — all on a physically-simulated year of data whose energy balance closes to zero. And the voice loop on top is real, end-to-end.**

*(end ≈ 1:58)*

---

## Three things that make or break the take
1. **Don't talk over the app's spoken reply** in the voice beat — that "Planned for the day…" line is the wow. Leave a 2-second gap.
2. **Mic = your Mac mic in the Simulator.** Say only the command while it's listening, then narrate after you tap stop. (Or type the command and narrate freely — the reply still speaks.)
3. **It's recorded, so retake freely** until the voice command lands cleanly and the numbers match the script (€2.72 / 69% / 55%). Set the clock to **Sunny demo** or **Live** before you start.
