# Competitive research — foundation for the pitch

Sourced landscape for "an assistant that tells you what to do" in home energy (DE, solar + battery + heat pump + EV). Use this to back the pitch claims — and to stay honest on stage (see guardrails at the bottom).

## The shape of the market: two camps, one empty seat

- **Silent automators** — do it *for* you without explaining: **Enpal.One+**, **Tibber** smart charging, **Octopus** Intelligent Go, **1KOMMA5° Heartbeat**.
- **Dashboards** — hand you charts to interpret *yourself*: **SolarEdge**, **Fronius Solar.web**, **SMA Energy**.
- **Empty seat:** nobody **forecasts + explains + advises + converses** in plain language. That's Lumen.

## Feature-gap table

| Competitor | Forward prices | Plain-language advice | Conversational assistant | Fault detection | Tells you what to do |
|---|:--:|:--:|:--:|:--:|:--:|
| **Enpal** (host) | ✗ (hidden in automation) | ✗ | ✗ | ~ basic outage only | ✗ silent auto |
| **Tibber** | ✓ today+tomorrow (15-min) | ✗ | ✗ support bot only | ✗ | ✗ silent auto |
| **Octopus** | ✓ half-hourly, day-ahead | ✗ static blogs | ✗ staff tool only | ✗ | ✗ silent auto |
| **SolarEdge** | ✗ | ✗ | ✗ | ✓ strong (panel-level) | ✗ dashboard |
| **Fronius** | ~ Premium/gated | ✗ | ✗ | ✓ service messages | ✗ dashboard |
| **SMA** | ✗ | ~ "recommended actions" | ✗ | ~ basic flags | ✗ dashboard |
| **1KOMMA5° Heartbeat** | ~ trades on it (in-app view unverified) | ✗ | ✗ | ? unverified | ✗ silent auto |

✓ yes · ~ partial/gated · ✗ none · ? unverified. **No competitor ticks both "conversational assistant" and "tells you what to do."**

## Supporting stats (Jobs-to-be-Done)

- **Dynamic tariffs are now mandatory but barely understood.** Since 1 Jan 2025 every German supplier must offer ≥1 dynamic tariff (§41a EnWG) — but only ~928k households (~20% of the 4.6M smart-meter rollout) are expected to be *eligible* by end-2025, and **53% of households don't know what dynamic tariffs are.** [§41a EnWG](https://www.gesetze-im-internet.de/enwg_2005/__41a.html) · [Finanztip](https://www.finanztip.de/presse/knapp-eine-million-haushalte-haben-die-wahl-dynamische-stromtarife-koennen-hunderte-euro-sparen/) · [vzbv](https://www.vzbv.de/pressemitteilungen/dynamische-stromtarife-19-millionen-haushalte-im-dunkeln)
- **Dashboards die within a month.** In-home-display engagement falls ~60% after the first 4 weeks; only ~20–30% still engage after 3–4 months — monitors get "backgrounded." [Energy & Buildings field study](https://www.sciencedirect.com/science/article/abs/pii/S0378778821005727) · [Hargreaves, Energy Policy 52:126–134](https://ideas.repec.org/a/eee/enepol/v52y2013icp126-134.html)
- **Soiling quietly costs ~5%/yr** (NREL typical; up to ~15%+ in dusty regions) — validates the dirty-panels demo. [NREL](https://docs.nrel.gov/docs/fy23osti/85776.pdf)
- **1-in-3 air-source heat pumps underperform** the SPF 2.5 threshold (UK RHPP field trial); improper install can raise HVAC energy ~30% (NIST). [DECC RHPP](https://assets.publishing.service.gov.uk/media/5a82b8faed915d74e62374d8/DECC_RHPP_161214_Final_Report_v1-13.pdf) · [NIST](https://www.nist.gov/news-events/news/2014/11/underperforming-energy-efficiency-hvac-equipment-suffers-due-poor)

## Honesty guardrails (do NOT overclaim on stage)

1. **Don't say monitoring apps have "no fault detection"** — SolarEdge has strong panel-level alerts; Fronius/SMA have service messages. Differentiate on *plain-language + heat-pump/soiling scope + conversational*, not presence.
2. **Don't say "nobody forecasts"** — SMA and Fronius (gated) do; SolarEdge doesn't.
3. **Don't say "nobody advises"** — SMA has basic "recommended actions."
4. **1KOMMA5°'s in-app forward price view and fault detection are unverified** — don't assert them.
5. **Don't quote a hard "X households on dynamic tariffs"** — use the eligibility / "53% don't know them" framing.

**The defensible line:** the gap isn't that competitors show nothing — it's that they either *automate silently* or *make you read charts*. None **explains and advises in plain language, on demand, conversationally.** That seat is empty.
