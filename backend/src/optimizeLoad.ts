/**
 * The planner. Finds the greenest window to run a flexible load, classifying energy by
 * SOURCE (free solar → battery → paid grid), not price. Sequential: already-committed loads
 * claim their solar/battery first, so the next device routes around them.
 *
 * Model (deterministic, defensible): at each 15-min slot the grabbable "free" power is the
 * solar currently exported to the grid (grid_export_kw) minus what committed loads already
 * claimed. Shortfall is drawn from stored solar (battery SoC at the window start), then from
 * the grid at that slot's retail price. Source-first objective: minimise grid cost.
 */
import { recordsArray, indexOf, household, TimeseriesRecord } from "./data";
import { commitmentsFor } from "./ledger";
import { Device } from "./devices";

const DT = 0.25;
export type Source = "free" | "partial" | "paid";
export type Objective = "cheapest" | "greenest" | "soonest";

export interface RibbonCell { hour: string; source: Source }
export interface DaySlot { hour: number; start: string; window: string; source: Source; ownSharePct: number; gridCostEur: number; feasible: boolean }
export interface OptimizeResult {
    device: string;
    deviceName: string;
    controllable: boolean;
    loadKwh: number;
    durationSlots: number;
    durationHours: number;
    start: string;
    end: string;
    window: string;            // "13:00–15:00"
    source: Source;
    ownSharePct: number;
    gridCostEur: number;
    breakdownKwh: { free: number; battery: number; grid: number };
    ribbon: RibbonCell[];
    slots: DaySlot[];          // per-start-hour evaluation across the day (for the interactive picker)
    rationale: string;
}

function hhmm(iso: string): string { return iso.slice(11, 16); }

export function optimizeLoad(householdId: string, device: Device, nowISO: string, deadlineISO?: string, objective: Objective = "cheapest"): OptimizeResult {
    const recs = recordsArray(householdId);
    const hh = household(householdId);
    const pmax = hh.battery_power_kw || 0;
    const nowIdx = indexOf(householdId, nowISO);
    if (nowIdx < 0) throw new Error("now timestamp not in series");
    const D = device.durationSlots;
    const dIdx = deadlineISO ? indexOf(householdId, deadlineISO) : -1;
    const horizonEnd = Math.min(recs.length - 1, dIdx > 0 ? dIdx : nowIdx + 96); // default 24h

    // committed loads → power claimed per absolute slot index
    const committed = commitmentsFor(householdId);
    const committedDraw = (t: number): number => {
        let p = 0;
        for (const c of committed) if (t >= c.startIdx && t < c.startIdx + c.durationSlots) p += c.powerKw;
        return p;
    };
    const freeSolarPower = (t: number) => Math.max(0, recs[t].grid_export_kw - committedDraw(t));

    function evalWindow(s: number) {
        let free = 0, battery = 0, grid = 0, cost = 0;
        let pool = recs[s].battery_soc_kwh; // stored solar available at window start
        for (let t = s; t < s + D; t++) {
            // committed loads drain the shared battery first (the part of their draw solar can't cover)
            const committedBatt = Math.max(0, committedDraw(t) - recs[t].grid_export_kw) * DT;
            pool = Math.max(0, pool - committedBatt);

            const draw = device.powerKw * DT;
            const useSolar = Math.min(draw, freeSolarPower(t) * DT);
            let rem = draw - useSolar;
            const useBatt = Math.min(rem, pool, pmax * DT);
            pool -= useBatt; rem -= useBatt;
            free += useSolar; battery += useBatt; grid += rem; cost += rem * recs[t].price_eur_per_kwh;
        }
        return { free, battery, grid, cost };
    }

    // kWh of already-committed load overlapping a candidate window — used to STAGGER tasks:
    // among equally-good (equally-green) windows, prefer the one that runs while the fewest
    // other planned loads are running. At solar noon every window is "free", so without this
    // every task would pile onto the earliest slot ("everything at 13:00"); spreading them
    // across the solar plateau turns the plan into a real, readable schedule while staying 100%
    // solar. It never trades cost for spread — staggering only breaks exact ties.
    const overlapAt = (s: number): number => { let o = 0; for (let t = s; t < s + D; t++) o += committedDraw(t) * DT; return o; };

    // search every feasible start; selection rule depends on the objective
    let bestS = nowIdx, best = evalWindow(nowIdx), bestOv = overlapAt(nowIdx);
    for (let s = nowIdx; s + D <= horizonEnd; s++) {
        const r = evalWindow(s);
        const ov = overlapAt(s);
        if (objective === "soonest") {
            // earliest feasible start wins — the "just run it now" mode; deliberately no staggering
            if (s < bestS) { best = r; bestS = s; bestOv = ov; }
        } else if (objective === "greenest") {
            // maximise own energy (free + battery); tie-break: less overlap (stagger), then cheaper
            const own = r.free + r.battery, bestOwn = best.free + best.battery;
            const better = own > bestOwn + 1e-9
                || (Math.abs(own - bestOwn) < 1e-9 && ov < bestOv - 1e-9)
                || (Math.abs(own - bestOwn) < 1e-9 && Math.abs(ov - bestOv) < 1e-9 && r.cost < best.cost - 1e-9);
            if (better) { best = r; bestS = s; bestOv = ov; }
        } else {
            // cheapest: minimise grid cost; tie-break: less overlap (stagger). Loop order keeps earliest on a full tie.
            const better = r.cost < best.cost - 1e-9
                || (Math.abs(r.cost - best.cost) < 1e-9 && ov < bestOv - 1e-9);
            if (better) { best = r; bestS = s; bestOv = ov; }
        }
    }

    const total = device.energyKwh;
    const own = best.free + best.battery;
    const ownSharePct = Math.min(100, Math.round((own / total) * 100));
    const source: Source = best.grid < 0.02 * total ? "free" : own > 0.02 * total ? "partial" : "paid";
    const startISO = recs[bestS].timestamp;
    const endISO = recs[Math.min(recs.length - 1, bestS + D)].timestamp;
    const window = `${hhmm(startISO)}–${hhmm(endISO)}`;

    // per-start-hour evaluation across the whole now-day (for the interactive picker)
    const date = recs[nowIdx].timestamp.slice(0, 10);
    const slots: DaySlot[] = [];
    for (let h = 0; h < 24; h++) {
        const iso = `${date}T${String(h).padStart(2, "0")}:00:00`;
        const s = indexOf(householdId, iso);
        const feasible = s >= 0 && s + D <= recs.length;
        if (!feasible) { slots.push({ hour: h, start: iso, window: "", source: "paid", ownSharePct: 0, gridCostEur: 0, feasible: false }); continue; }
        const r = evalWindow(s);
        const o = r.free + r.battery;
        const src: Source = r.grid < 0.02 * total ? "free" : o > 0.02 * total ? "partial" : "paid";
        const endH = recs[Math.min(recs.length - 1, s + D)].timestamp;
        slots.push({ hour: h, start: iso, window: `${hhmm(iso)}–${hhmm(endH)}`, source: src, ownSharePct: Math.min(100, Math.round((o / total) * 100)), gridCostEur: round(r.cost, 2), feasible: true });
    }

    return {
        device: device.id,
        deviceName: device.name,
        controllable: device.controllable,
        loadKwh: round(total, 2),
        durationSlots: D,
        durationHours: round(D * DT, 2),
        start: startISO,
        end: endISO,
        window,
        source,
        ownSharePct,
        gridCostEur: round(best.cost, 2),
        breakdownKwh: { free: round(best.free, 2), battery: round(best.battery, 2), grid: round(best.grid, 2) },
        ribbon: dayRibbon(recs, nowIdx, freeSolarPower, device.powerKw),
        slots,
        rationale: rationale(source, device, window, ownSharePct, round(best.cost, 2)),
    };
}

/** Colour the now-day by source for a load of this size — green midday, red at night. */
function dayRibbon(recs: TimeseriesRecord[], nowIdx: number, freeSolarPower: (t: number) => number, powerKw: number): RibbonCell[] {
    const date = recs[nowIdx].timestamp.slice(0, 10);
    const cells: RibbonCell[] = [];
    for (let h = 0; h < 24; h++) {
        const iso = `${date}T${String(h).padStart(2, "0")}:00:00`;
        const t = recs.findIndex((r) => r.timestamp === iso);
        if (t < 0) continue;
        const fs = freeSolarPower(t);
        let source: Source;
        if (fs >= powerKw * 0.9) source = "free";
        else if (fs > 0.05 || recs[t].battery_soc_kwh > 0.5) source = "partial";
        else source = "paid";
        cells.push({ hour: `${String(h).padStart(2, "0")}:00`, source });
    }
    return cells;
}

function rationale(source: Source, device: Device, window: string, ownPct: number, cost: number): string {
    switch (source) {
        case "free":
            return `Your panels make more than the house needs around ${window} — the ${device.name.toLowerCase()} rides that surplus for free.`;
        case "partial":
            return `Around ${window}, ${ownPct}% comes from your own solar and battery; the rest is cheap grid (about €${cost.toFixed(2)}).`;
        default:
            return `No solar left to spare around ${window} — this run is about €${cost.toFixed(2)} from the grid. Midday tomorrow would be free.`;
    }
}

function round(v: number, dp: number): number { const f = 10 ** dp; return Math.round(v * f) / f; }
