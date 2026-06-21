/**
 * Live heat-pump anomaly detection — the math behind the "needs a look" card.
 *
 * Principle (energy-assistant-brief.md): tools own the numbers, the LLM owns the words.
 * This module produces *evidence only* (no prose): it weather-normalises the heat pump's
 * consumption against the home's OWN history, so it can tell "it's just cold out" apart
 * from "something is wrong". The causal narrative is left to the assistant (openaiChat.ts).
 */
import { recordsArray, household } from "./data";

const SLOT_HOURS = 0.25;      // 15-min records
const EXCESS_FACTOR = 1.4;    // a day counts as anomalous at >40% over weather-expected
const MIN_RUN_DAYS = 3;       // sustained, not a one-off spike
const WINDOW_DAYS = 21;       // how far back from "now" we look
const RECENCY_DAYS = 3;       // the run must still be live (ends within N days of now)
const TEMP_BUCKET_C = 2;      // baseline resolution
const MIN_EXPECTED_KWH = 5;   // ignore shoulder/summer days where the pump barely runs

// Solar (PV-soiling) detection — the mirror image: a sustained SHORTFALL on sunny days.
const SOLAR_SHORTFALL_FACTOR = 0.7;  // a day is anomalous at <70% of weather-expected yield
const MIN_EXPECTED_PV_KWH = 20;      // only flag real-sun days (skip dim/winter days)

interface DayAgg {
    date: string;             // YYYY-MM-DD
    hpKwh: number;
    pvKwh: number;
    houseKwh: number;
    meanTempC: number;
}

/** One structured, prose-free finding. The chat tool hands this to the LLM verbatim. */
export interface AnomalyEvidence {
    period: string;           // "YYYY-MM-DD..YYYY-MM-DD"
    days: number;
    observedKwAvg: number;    // mean heat-pump draw over the run
    expectedKwAvg: number;    // weather-expected draw at the same temperatures
    pctOver: number;
    tempRangeC: [number, number];
    otherLoadsNormal: boolean; // is the excess isolated to the heat pump?
    detail: string;           // deterministic one-liner for the card (no LLM needed)
}

const _dayCache = new Map<string, DayAgg[]>();
function dailyAggregates(id: string): DayAgg[] {
    let days = _dayCache.get(id);
    if (days) return days;
    const byDate = new Map<string, { hp: number; pv: number; house: number; temps: number[] }>();
    for (const r of recordsArray(id)) {
        const d = r.timestamp.slice(0, 10);
        let a = byDate.get(d);
        if (!a) { a = { hp: 0, pv: 0, house: 0, temps: [] }; byDate.set(d, a); }
        a.hp += r.heatpump_kw * SLOT_HOURS;
        a.pv += r.pv_production_kw * SLOT_HOURS;
        a.house += r.house_load_kw * SLOT_HOURS;
        a.temps.push(r.outdoor_temp_c);
    }
    days = [...byDate.entries()]
        .map(([date, a]) => ({ date, hpKwh: a.hp, pvKwh: a.pv, houseKwh: a.house, meanTempC: mean(a.temps) }))
        .sort((x, y) => x.date.localeCompare(y.date));
    _dayCache.set(id, days);
    return days;
}

/** Expected daily kWh of `value` as a function of mean outdoor temp, learnt from the home itself. */
function tempBaseline(days: DayAgg[], value: (d: DayAgg) => number): (t: number) => number {
    const buckets = new Map<number, number[]>();
    for (const d of days) {
        const b = Math.floor(d.meanTempC / TEMP_BUCKET_C) * TEMP_BUCKET_C;
        (buckets.get(b) ?? buckets.set(b, []).get(b)!).push(value(d));
    }
    // Median per bucket → robust: a single bad week can't move the baseline.
    const med = new Map<number, number>();
    for (const [b, vals] of buckets) med.set(b, median(vals));
    return (t: number) => {
        const target = Math.floor(t / TEMP_BUCKET_C) * TEMP_BUCKET_C;
        if (med.has(target)) return med.get(target)!;
        // nearest populated bucket
        let best = NaN, bestDist = Infinity;
        for (const [b, m] of med) {
            const dist = Math.abs(b - target);
            if (dist < bestDist) { bestDist = dist; best = m; }
        }
        return isNaN(best) ? 0 : best;
    };
}

/**
 * Find a sustained, still-active heat-pump anomaly as of `nowISO`.
 * Uses only complete days strictly before "now" — no peeking at the future.
 */
export function detectHeatpumpAnomaly(id: string, nowISO: string): AnomalyEvidence | null {
    if (!household(id).heat_pump) return null;

    const days = dailyAggregates(id);
    const baseline = tempBaseline(days, (d) => d.hpKwh);
    const houseMedian = median(days.map((d) => d.houseKwh));

    const nowDate = nowISO.slice(0, 10);
    const recent = days.filter((d) => d.date < nowDate).slice(-WINDOW_DAYS);
    if (recent.length < MIN_RUN_DAYS) return null;

    const flagged = recent.map((d) => {
        const exp = baseline(d.meanTempC);
        return { ...d, exp, anomalous: exp >= MIN_EXPECTED_KWH && d.hpKwh > exp * EXCESS_FACTOR };
    });

    // Most recent anomalous day, then walk back to the start of its contiguous run.
    let end = flagged.length - 1;
    while (end >= 0 && !flagged[end].anomalous) end--;
    if (end < 0) return null;
    let start = end;
    while (start - 1 >= 0 && flagged[start - 1].anomalous) start--;

    const run = flagged.slice(start, end + 1);
    if (run.length < MIN_RUN_DAYS) return null;
    if (daysBetween(run[run.length - 1].date, nowDate) > RECENCY_DAYS) return null; // stale

    const observedKwh = mean(run.map((d) => d.hpKwh));
    const expectedKwh = mean(run.map((d) => d.exp));
    const pctOver = (observedKwh / expectedKwh - 1) * 100;
    const temps = run.map((d) => d.meanTempC);
    const houseRun = median(run.map((d) => d.houseKwh));
    const otherLoadsNormal = Math.abs(houseRun - houseMedian) <= houseMedian * 0.3;

    return {
        period: `${run[0].date}..${run[run.length - 1].date}`,
        days: run.length,
        observedKwAvg: round(observedKwh / 24, 2),
        expectedKwAvg: round(expectedKwh / 24, 2),
        pctOver: round(pctOver, 0),
        tempRangeC: [round(Math.min(...temps), 1), round(Math.max(...temps), 1)],
        otherLoadsNormal,
        detail: `Heat-pump electricity is ~${Math.round(pctOver)}% above what these temperatures normally need (${round(observedKwh / 24, 1)} kW vs ~${round(expectedKwh / 24, 1)} kW), sustained ${run.length} days.`,
    };
}

/** One structured, prose-free finding for an under-performing-solar (soiling) run. */
export interface SolarAnomalyEvidence {
    period: string;            // "YYYY-MM-DD..YYYY-MM-DD"
    days: number;
    observedDailyKwh: number;  // mean PV yield over the run
    expectedDailyKwh: number;  // weather-expected yield on comparably sunny days
    pctUnder: number;
    tempRangeC: [number, number];
    detail: string;            // deterministic one-liner for the card (no LLM needed)
}

/**
 * Find a sustained, still-active solar SHORTFALL as of `nowISO` — the soiling/shading mirror of
 * the heat-pump detector. Weather-normalises daily PV yield against the home's OWN history at the
 * same temperatures, so a genuinely cloudy stretch reads differently from dirty panels.
 */
export function detectSolarAnomaly(id: string, nowISO: string): SolarAnomalyEvidence | null {
    if (!(household(id).pv_kwp > 0)) return null;

    const days = dailyAggregates(id);
    const baseline = tempBaseline(days, (d) => d.pvKwh);

    const nowDate = nowISO.slice(0, 10);
    const recent = days.filter((d) => d.date < nowDate).slice(-WINDOW_DAYS);
    if (recent.length < MIN_RUN_DAYS) return null;

    const flagged = recent.map((d) => {
        const exp = baseline(d.meanTempC);
        return { ...d, exp, anomalous: exp >= MIN_EXPECTED_PV_KWH && d.pvKwh < exp * SOLAR_SHORTFALL_FACTOR };
    });

    let end = flagged.length - 1;
    while (end >= 0 && !flagged[end].anomalous) end--;
    if (end < 0) return null;
    let start = end;
    while (start - 1 >= 0 && flagged[start - 1].anomalous) start--;

    const run = flagged.slice(start, end + 1);
    if (run.length < MIN_RUN_DAYS) return null;
    if (daysBetween(run[run.length - 1].date, nowDate) > RECENCY_DAYS) return null; // stale

    const observed = mean(run.map((d) => d.pvKwh));
    const expected = mean(run.map((d) => d.exp));
    const pctUnder = (1 - observed / expected) * 100;
    const temps = run.map((d) => d.meanTempC);

    return {
        period: `${run[0].date}..${run[run.length - 1].date}`,
        days: run.length,
        observedDailyKwh: round(observed, 1),
        expectedDailyKwh: round(expected, 1),
        pctUnder: round(pctUnder, 0),
        tempRangeC: [round(Math.min(...temps), 1), round(Math.max(...temps), 1)],
        detail: `Solar is generating ~${Math.round(pctUnder)}% less than these sunny days normally yield (${Math.round(observed)} kWh/day vs ~${Math.round(expected)}), sustained ${run.length} days.`,
    };
}

// helpers
function mean(xs: number[]): number { return xs.reduce((a, b) => a + b, 0) / xs.length; }
function median(xs: number[]): number {
    const s = [...xs].sort((a, b) => a - b);
    const m = Math.floor(s.length / 2);
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}
function daysBetween(aDate: string, bDate: string): number {
    return Math.round((Date.parse(bDate) - Date.parse(aDate)) / 86_400_000);
}
function round(v: number, dp: number): number { const f = 10 ** dp; return Math.round(v * f) / f; }
