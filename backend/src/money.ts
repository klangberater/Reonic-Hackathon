/** Month-end bill forecast + earned-from-solar, from month-to-date actuals at the virtual "now". */
import { recordsArray, indexOf, contract, billsFor } from "./data";

const DT = 0.25;

export interface MoneyForecast {
    month: string;
    costToDateEur: number;
    projectedTotalEur: number;
    earnedFromSolarEur: number;     // feed-in credit, projected
    daysElapsed: number;
    daysInMonth: number;
    earning: boolean;               // projected total < 0 → the home earns money this month
}

export function moneyForecast(householdId: string, nowISO: string): MoneyForecast {
    const recs = recordsArray(householdId);
    const month = nowISO.slice(0, 7);
    const c = contract(householdId);
    const feedIn = c.feed_in_eur_per_kwh;
    const baseFee = c.base_fee_eur_per_month;

    const nowIdx = indexOf(householdId, nowISO);
    let importCost = 0, exportKwh = 0, firstIdx = -1, lastIdx = nowIdx;
    for (let i = 0; i <= nowIdx; i++) {
        if (recs[i].timestamp.slice(0, 7) !== month) continue;
        if (firstIdx < 0) firstIdx = i;
        importCost += recs[i].grid_import_kw * DT * recs[i].price_eur_per_kwh;
        exportKwh += recs[i].grid_export_kw * DT;
    }
    const slotsElapsed = nowIdx - firstIdx + 1;
    const daysElapsed = Math.max(1, Math.round(slotsElapsed / 96));
    const daysInMonth = new Date(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 0).getDate();
    const frac = slotsElapsed / (daysInMonth * 96);

    const earnedToDate = exportKwh * feedIn;
    const costToDate = importCost + baseFee * (slotsElapsed / (daysInMonth * 96)) - earnedToDate;
    const projectedTotal = (importCost / frac) + baseFee - (earnedToDate / frac);
    const earnedProjected = earnedToDate / frac;

    return {
        month,
        costToDateEur: round(costToDate, 2),
        projectedTotalEur: round(projectedTotal, 0),
        earnedFromSolarEur: round(earnedProjected, 2),
        daysElapsed,
        daysInMonth,
        earning: projectedTotal < 0,
    };
}

function round(v: number, dp: number): number { const f = 10 ** dp; return Math.round(v * f) / f; }
