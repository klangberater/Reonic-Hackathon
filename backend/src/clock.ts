/**
 * "Now". The default/summer clock tracks the REAL wall clock: the dataset spans all of 2026 at
 * 15-min resolution, so the live timestamp (pinned to the data year) always exists in it. Winter
 * stays pinned to a cold January morning for the heat-pump-anomaly demo moment.
 */
const DATA_YEAR = 2026;

export const CLOCKS: Record<string, string> = {
    winter: "2026-01-15T08:00:00", // cold morning, heat pump heavy (fixed demo scenario)
};

export function resolveNow(clock?: string, at?: string): string {
    if (at) return at;                               // explicit override (scripted demos / tests)
    const c = clock || process.env.DEMO_CLOCK || "summer";
    if (c === "winter") return CLOCKS.winter;
    return liveNow();                                // summer / default → live real time
}

/** Real Europe/Berlin wall-clock now, floored to the 15-min grid and pinned to the data year. */
export function liveNow(date: Date = new Date()): string {
    const parts = new Intl.DateTimeFormat("en-GB", {
        timeZone: "Europe/Berlin", hourCycle: "h23",
        month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit",
    }).formatToParts(date);
    const v = (t: string) => parts.find((p) => p.type === t)!.value;
    const min = String(Math.floor(parseInt(v("minute"), 10) / 15) * 15).padStart(2, "0");
    return `${DATA_YEAR}-${v("month")}-${v("day")}T${v("hour")}:${min}:00`;
}
