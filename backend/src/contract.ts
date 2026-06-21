/**
 * Contract / tariff read-model. Surfaces the genuinely contractual fields (term, notice
 * period, renewal, terms text) the rest of the app ignores, and computes the notice deadline
 * and days-remaining relative to "now". Used by GET /contract and the get_contract chat tool.
 */
import { contract, tariff } from "./data";

export interface ContractSummary {
    provider: string;
    customerName: string;
    tariffId: string;
    tariffName: string;
    tariffType: string;            // e.g. "dynamic_hourly"
    pricingModel: string;
    baseFeeEurPerMonth: number;
    feedInEurPerKwh: number;
    spotAdderEurPerKwh: number | null;
    contractStart: string;         // YYYY-MM-DD
    contractEnd: string;           // YYYY-MM-DD
    minimumTermMonths: number;
    noticePeriodWeeks: number;
    autoRenewMonths: number;
    noticeByDate: string;          // YYYY-MM-DD — give notice on/before this or it auto-renews
    daysUntilEnd: number;          // relative to "now" (can be negative once past)
    daysUntilNoticeDeadline: number;
    inNoticeWindow: boolean;       // now is within [noticeBy, contractEnd]
    termsText: string;
}

const DAY = 86_400_000;
function dayUTC(yyyyMmDd: string): Date { return new Date(`${yyyyMmDd}T00:00:00Z`); }
function daysBetween(a: Date, b: Date): number { return Math.round((a.getTime() - b.getTime()) / DAY); }

export function contractSummary(householdId: string, nowISO: string): ContractSummary {
    const c = contract(householdId);
    const t = tariff(c.tariff_id);
    const end = dayUTC(c.contract_end);
    const noticeBy = new Date(end.getTime() - c.notice_period_weeks * 7 * DAY);
    const now = dayUTC(nowISO.slice(0, 10));
    return {
        provider: c.provider,
        customerName: c.customer_name,
        tariffId: c.tariff_id,
        tariffName: c.tariff_name,
        tariffType: t?.type ?? c.energy_pricing?.model ?? "",
        pricingModel: c.energy_pricing?.model ?? "",
        baseFeeEurPerMonth: c.base_fee_eur_per_month,
        feedInEurPerKwh: c.feed_in_eur_per_kwh,
        spotAdderEurPerKwh: c.energy_pricing?.spot_adder_eur_per_kwh ?? null,
        contractStart: c.contract_start,
        contractEnd: c.contract_end,
        minimumTermMonths: c.minimum_term_months,
        noticePeriodWeeks: c.notice_period_weeks,
        autoRenewMonths: c.auto_renew_months,
        noticeByDate: noticeBy.toISOString().slice(0, 10),
        daysUntilEnd: daysBetween(end, now),
        daysUntilNoticeDeadline: daysBetween(noticeBy, now),
        inNoticeWindow: now >= noticeBy && now <= end,
        termsText: c.contract_terms_text,
    };
}
