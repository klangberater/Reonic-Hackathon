/**
 * Data-access layer over the coherent demo dataset in ../../data.
 * Loads + indexes lazily and caches (timeseries files are ~19 MB each).
 */
import fs from "fs";
import path from "path";

const DATA_DIR = path.resolve(__dirname, "..", "..", "data");

export interface TimeseriesRecord {
    timestamp: string;
    outdoor_temp_c: number;
    pv_production_kw: number;
    house_load_kw: number;
    heatpump_kw: number;
    ev_charging_kw: number;
    total_consumption_kw: number;
    battery_charge_kw: number;
    battery_discharge_kw: number;
    battery_soc_kwh: number;
    battery_soc_pct: number;
    grid_import_kw: number;
    grid_export_kw: number;
    price_eur_per_kwh: number;
}

export interface Household {
    household_id: string;
    name: string;
    city: string;
    residents: number;
    pv_kwp: number;
    battery_kwh: number;
    battery_power_kw: number;
    heat_pump: boolean;
    ev_charger: boolean;
    tariff_id: string;
    timeseries_file: string;
}

export interface Contract {
    household_id: string;
    customer_name: string;
    provider: string;
    tariff_id: string;
    tariff_name: string;
    contract_start: string;
    contract_end: string;
    minimum_term_months: number;
    notice_period_weeks: number;
    auto_renew_months: number;
    base_fee_eur_per_month: number;
    feed_in_eur_per_kwh: number;
    energy_pricing: { model: string; spot_adder_eur_per_kwh?: number; energy_rate_eur_per_kwh?: number };
    assets: { pv_kwp: number; battery_kwh: number; heat_pump: boolean; heat_pump_kw: number; ev_charger: boolean; ev_battery_kwh: number };
    contract_terms_text: string;
}

export interface MonthlyBill {
    household_id: string; month: string;
    consumption_kwh: number; pv_production_kwh: number;
    grid_import_kwh: number; grid_export_kwh: number;
    energy_cost_eur: number; base_fee_eur: number; feed_in_credit_eur: number;
    total_bill_eur: number; self_sufficiency_pct: number;
}

function readJson<T>(file: string): T {
    return JSON.parse(fs.readFileSync(path.join(DATA_DIR, file), "utf8")) as T;
}

let _households: Household[] | null = null;
export function households(): Household[] {
    if (!_households) _households = readJson<Household[]>("households.json");
    return _households;
}
export function household(id: string): Household {
    const hh = households().find((h) => h.household_id === id);
    if (!hh) throw new Error(`unknown household: ${id}`);
    return hh;
}

let _contracts: Contract[] | null = null;
export function contract(id: string): Contract {
    if (!_contracts) _contracts = readJson<Contract[]>("contracts.json");
    const c = _contracts.find((x) => x.household_id === id);
    if (!c) throw new Error(`no contract: ${id}`);
    return c;
}

let _tariffs: any[] | null = null;
export function tariff(id: string): any {
    if (!_tariffs) _tariffs = readJson<any[]>("tariffs.json");
    const t = _tariffs.find((x) => x.tariff_id === id);
    if (!t) throw new Error(`no tariff: ${id}`);
    return t;
}

let _bills: MonthlyBill[] | null = null;
export function billsFor(id: string): MonthlyBill[] {
    if (!_bills) _bills = readJson<MonthlyBill[]>("monthly_bills.json");
    return _bills.filter((b) => b.household_id === id);
}

interface Series { records: TimeseriesRecord[]; index: Map<string, number> }
const _seriesCache = new Map<string, Series>();
function series(id: string): Series {
    let s = _seriesCache.get(id);
    if (!s) {
        const raw = readJson<{ records: TimeseriesRecord[] }>(household(id).timeseries_file);
        const index = new Map(raw.records.map((r, i) => [r.timestamp, i]));
        s = { records: raw.records, index };
        _seriesCache.set(id, s);
    }
    return s;
}
export function recordsArray(id: string): TimeseriesRecord[] { return series(id).records; }
export function indexOf(id: string, iso: string): number {
    const i = series(id).index.get(iso);
    return i === undefined ? -1 : i;
}
export function recordAt(id: string, iso: string): TimeseriesRecord | undefined {
    const i = indexOf(id, iso);
    return i < 0 ? undefined : series(id).records[i];
}
