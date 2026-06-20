import { contract } from "./data";

export interface Device {
    id: string;
    name: string;
    icon: string;
    energyKwh: number;
    durationSlots: number; // 15-min slots
    powerKw: number;
    controllable: boolean;  // true = real automation (wallbox); false = reminder/delay-start
}

const DT = 0.25;

/** Seeded appliance library; EV is derived from the household's contract. */
export function devicesFor(householdId: string): Device[] {
    const list: Device[] = [
        appliance("dishwasher", "Dishwasher", "bowl", 1.2, 8),       // 2.0h
        appliance("washing_machine", "Washing machine", "wash", 0.9, 6), // 1.5h
    ];
    const c = contract(householdId);
    if (c.assets.ev_charger && c.assets.ev_battery_kwh > 0) {
        // A typical evening top-up of ~18 kWh at the wallbox.
        const energy = 18;
        const powerKw = 11;
        const durationSlots = Math.ceil(energy / powerKw / DT); // ~8 slots (2h)
        list.unshift({ id: "ev", name: "Car", icon: "car", energyKwh: energy, durationSlots, powerKw, controllable: true });
    }
    return list;
}

export function deviceById(householdId: string, id: string): Device {
    const d = devicesFor(householdId).find((x) => x.id === id);
    if (!d) throw new Error(`unknown device: ${id}`);
    return d;
}

function appliance(id: string, name: string, icon: string, energyKwh: number, durationSlots: number): Device {
    return { id, name, icon, energyKwh, durationSlots, powerKw: energyKwh / (durationSlots * DT), controllable: false };
}
