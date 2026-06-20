/**
 * Thin data-access layer over the coherent demo dataset in ../../data.
 * Loads + indexes lazily and caches in memory (the timeseries files are ~19 MB each).
 */
import fs from "fs";
import path from "path";

// backend/dist/data.js -> ../../data = <repo>/data
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
  heat_pump: boolean;
  ev_charger: boolean;
  tariff_id: string;
  timeseries_file: string;
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

const _seriesCache = new Map<string, Map<string, TimeseriesRecord>>();

/** Records for a household, indexed by ISO timestamp. Cached after first load. */
export function seriesByTimestamp(id: string): Map<string, TimeseriesRecord> {
  let idx = _seriesCache.get(id);
  if (!idx) {
    const file = household(id).timeseries_file;
    const raw = readJson<{ records: TimeseriesRecord[] }>(file);
    idx = new Map(raw.records.map((r) => [r.timestamp, r]));
    _seriesCache.set(id, idx);
  }
  return idx;
}

export const DATA_DIR_PATH = DATA_DIR;
