/**
 * Multi-task day planner. Places each requested task in deadline order, committing it so the
 * next task routes around it (shared ledger). Returns the day's solar curve and aggregate
 * savings vs. running every task immediately. Computes AND commits — re-plan/mode-toggle/nudge
 * just call this again; addCommitment replaces per device, so it is idempotent.
 */
import { recordsArray, indexOf, household } from "./data";
import { Device, deviceById, evDevice } from "./devices";
import { optimizeLoad, Objective, Source } from "./optimizeLoad";
import { addCommitment, ledgerRemove } from "./ledger";

const DT = 0.25;
const CO2_KG_PER_KWH = 0.40;   // German grid average

export interface PlanTaskInput { device: string; deadline?: string; target?: number; start?: string }
export interface PlannedTask {
    device: string; name: string; icon: string; start: string; startHour: number;
    window: string; durationHours: number; source: Source; ownSharePct: number;
    gridCostEur: number; controllable: boolean;
}
export interface CurvePoint { hour: number; solarKw: number }
export interface PlanResult {
    mode: Objective; solarSharePct: number; savedEur: number; savedCo2Kg: number;
    curve: CurvePoint[]; tasks: PlannedTask[];
}

function buildDevice(householdId: string, t: PlanTaskInput): Device {
    return t.device === "ev" ? evDevice(householdId, t.target ?? 80) : deviceById(householdId, t.device);
}
function hourOf(iso: string): number { return parseInt(iso.slice(11, 13), 10); }
function round(v: number, dp: number): number { const f = 10 ** dp; return Math.round(v * f) / f; }

/**
 * Cost + grid kWh if this device ran starting at nowISO — the "do it now" baseline we measure
 * savings against. Intentionally evaluates the device in isolation (ignores other committed
 * loads): it answers "what would this one task cost if I just ran it right now".
 */
function baselineAt(householdId: string, device: Device, nowISO: string): { cost: number; gridKwh: number } {
    const recs = recordsArray(householdId);
    const s = indexOf(householdId, nowISO);
    let grid = 0, cost = 0;
    let pool = recs[s].battery_soc_kwh;
    const pmax = household(householdId).battery_power_kw || 0;
    for (let t = s; t < s + device.durationSlots && t < recs.length; t++) {
        const draw = device.powerKw * DT;
        const useSolar = Math.min(draw, Math.max(0, recs[t].grid_export_kw) * DT);
        let rem = draw - useSolar;
        const useBatt = Math.min(rem, pool, pmax * DT);
        pool -= useBatt; rem -= useBatt;
        grid += rem; cost += rem * recs[t].price_eur_per_kwh;
    }
    return { cost, gridKwh: grid };
}

export function planDay(householdId: string, nowISO: string, mode: Objective, inputs: PlanTaskInput[]): PlanResult {
    // replace prior commitments for exactly the devices being (re)planned
    for (const t of inputs) ledgerRemove(householdId, t.device);

    // pinned tasks first (so the rest route around them), then by deadline ascending
    const ordered = [...inputs].sort((a, b) => {
        if (!!a.start !== !!b.start) return a.start ? -1 : 1;
        return (a.deadline ?? "").localeCompare(b.deadline ?? "");
    });

    const tasks: PlannedTask[] = [];
    let totalOwn = 0, totalKwh = 0, planGridKwh = 0, planCost = 0;
    let baseGridKwh = 0, baseCost = 0;

    for (const input of ordered) {
        const device = buildDevice(householdId, input);
        const r = optimizeLoad(householdId, device, nowISO, input.deadline, mode);
        // honor a pin only if it lands on a real slot; otherwise fall back to the planner's pick
        const pinValid = input.start != null && indexOf(householdId, input.start) >= 0;
        const start = pinValid ? input.start! : r.start;
        // if pinned, re-evaluate metrics at the pinned start by asking the planner with no search room
        const placed = pinValid
            ? optimizeLoad(householdId, device, input.start!, input.deadline, "soonest")  // forces start == pinned
            : r;
        const startIdx = indexOf(householdId, start);
        addCommitment({
            householdId, device: device.id, deviceName: device.name, startISO: start,
            startIdx, durationSlots: device.durationSlots, powerKw: device.powerKw, source: placed.source,
        });

        const own = placed.breakdownKwh.free + placed.breakdownKwh.battery;
        totalOwn += own; totalKwh += device.energyKwh;
        planGridKwh += placed.breakdownKwh.grid; planCost += placed.gridCostEur;

        const base = baselineAt(householdId, device, nowISO);
        baseGridKwh += base.gridKwh; baseCost += base.cost;

        tasks.push({
            device: device.id, name: device.name, icon: device.icon, start,
            startHour: hourOf(start), window: placed.window, durationHours: round(device.durationSlots * DT, 2),
            source: placed.source, ownSharePct: device.energyKwh > 0 ? Math.min(100, Math.round((own / device.energyKwh) * 100)) : 0,
            gridCostEur: round(placed.gridCostEur, 2), controllable: device.controllable,
        });
    }

    // solar curve, hours 06..23 of the now-day
    const date = nowISO.slice(0, 10);
    const recs = recordsArray(householdId);
    const curve: CurvePoint[] = [];
    for (let h = 6; h <= 23; h++) {
        const i = indexOf(householdId, `${date}T${String(h).padStart(2, "0")}:00:00`);
        curve.push({ hour: h, solarKw: i >= 0 ? round(recs[i].pv_production_kw, 2) : 0 });
    }

    return {
        mode,
        solarSharePct: totalKwh > 0 ? Math.min(100, Math.round((totalOwn / totalKwh) * 100)) : 0,
        savedEur: round(Math.max(0, baseCost - planCost), 2),
        savedCo2Kg: round(Math.max(0, (baseGridKwh - planGridKwh) * CO2_KG_PER_KWH), 1),
        curve,
        tasks,
    };
}
