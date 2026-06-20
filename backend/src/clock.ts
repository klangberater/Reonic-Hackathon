/** Virtual "now": the data is historical, so we anchor "now" to a chosen timestamp. */
export const CLOCKS: Record<string, string> = {
    summer: "2026-06-20T13:00:00", // Sat heatwave, solar peaking
    winter: "2026-01-15T08:00:00", // cold morning, heat pump heavy
};

export function resolveNow(clock?: string, at?: string): string {
    if (at) return at;
    return CLOCKS[clock || process.env.DEMO_CLOCK || "summer"] || CLOCKS.summer;
}
