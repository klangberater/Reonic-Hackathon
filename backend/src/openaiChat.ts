/**
 * The grounded assistant. OpenAI does the words; our planner functions do the math.
 * A function-calling loop: GPT calls tools (bound to the current home + virtual "now"),
 * we execute them against the data layer, feed results back, GPT writes the plain-language answer.
 */
import { household, contract, tariff } from "./data";
import { resolveNow, CLOCKS } from "./clock";
import { devicesFor, deviceById } from "./devices";
import { optimizeLoad } from "./optimizeLoad";
import { moneyForecast } from "./money";
import { commitmentsFor } from "./ledger";
import { snapshotFor, insightsFor as insightsBundle } from "./views";

const MODEL = process.env.OPENAI_MODEL || "gpt-4o";
const MAX_TURNS = 6;

interface Msg { role: string; content: string | null; tool_calls?: any[]; tool_call_id?: string; name?: string }

const TOOLS = [
    fn("get_now", "Live snapshot: solar, consumption, battery SoC, grid flow, price, outdoor temp.", {}),
    fn("get_money", "Month-end bill forecast and earned-from-solar for the current month.", {}),
    fn("get_household", "The home's assets (PV, battery, heat pump, EV) and tariff.", {}),
    fn("get_devices", "Flexible devices (car, dishwasher, washing machine) and whether each is scheduled.", {}),
    fn("get_insights", "Proactive anomalies and nudges, plus overall health (ok/alert).", {}),
    fn("list_commitments", "Loads the user has already scheduled (the committed-loads ledger).", {}),
    fn("optimize_load", "Best (greenest) time to run a device, with source (free/partial/paid), own-share %, grid cost and a rationale. Routes around already-committed loads.", {
        device: { type: "string", description: "device id: ev, dishwasher, or washing_machine" },
        deadline: { type: "string", description: "optional ISO timestamp the run must finish by" },
    }, ["device"]),
];

function fn(name: string, description: string, props: Record<string, any>, required: string[] = []) {
    return { type: "function", function: { name, description, parameters: { type: "object", properties: props, required, additionalProperties: false } } };
}

function systemPrompt(householdId: string, nowISO: string, clock: string): string {
    const h = household(householdId); const c = contract(householdId); const t = tariff(h.tariff_id);
    const assets = [
        `${h.pv_kwp} kWp solar`,
        h.battery_kwh > 0 ? `${h.battery_kwh} kWh battery` : "no battery",
        h.heat_pump ? "a heat pump" : null,
        h.ev_charger ? `an EV (${c.assets.ev_battery_kwh} kWh)` : null,
    ].filter(Boolean).join(", ");
    return [
        `You are Lumen, a calm, plain-spoken home-energy assistant for ${h.name} in ${h.city}.`,
        `Their home has ${assets}. Tariff: ${t.name} (${t.type}).`,
        `The current time ("now") is ${nowISO} (${clock}).`,
        `Rules:`,
        `- ALWAYS call tools for any number, time, price or status. Never invent or estimate figures.`,
        `- Think in terms of energy SOURCE: free (your solar or battery) vs paid (grid). Money in euros.`,
        `- get_money: when "earning" is true the home is NET POSITIVE this month — a negative projected_total_eur is a CREDIT, not a cost. Say "you're on track to earn about €X", never "costs €X".`,
        `- To answer "when should I run X" or "is now a good time", call optimize_load for that device.`,
        `- Keep answers to 1–3 short sentences, warm and concrete. No JSON, no jargon, no markdown tables.`,
    ].join("\n");
}

function makeExecutor(householdId: string, nowISO: string) {
    return async (name: string, args: any): Promise<unknown> => {
        switch (name) {
            case "get_now": return snapshotFor(householdId, nowISO);
            case "get_money": return moneyForecast(householdId, nowISO);
            case "get_household": { const h = household(householdId); const c = contract(householdId); return { ...h, ev_battery_kwh: c.assets.ev_battery_kwh, tariff: tariff(h.tariff_id) }; }
            case "get_devices": return devicesFor(householdId).map((d) => ({ id: d.id, name: d.name, energy_kwh: d.energyKwh, controllable: d.controllable }));
            case "get_insights": return insightsBundle(householdId, nowISO);
            case "list_commitments": return commitmentsFor(householdId);
            case "optimize_load": {
                try { return optimizeLoad(householdId, deviceById(householdId, String(args.device)), nowISO, args.deadline); }
                catch (e: any) { return { error: String(e.message || e) }; }
            }
            default: return { error: `unknown tool ${name}` };
        }
    };
}

export interface ChatResult { reply: string; toolsUsed: string[] }

export async function runChat(householdId: string, clock: string | undefined, message: string, history: Msg[]): Promise<ChatResult> {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) throw Object.assign(new Error("assistant not configured (no OPENAI_API_KEY)"), { code: 503 });
    const nowISO = resolveNow(clock);
    const clockName = clock && CLOCKS[clock] ? clock : "summer";
    const exec = makeExecutor(householdId, nowISO);

    const messages: Msg[] = [
        { role: "system", content: systemPrompt(householdId, nowISO, clockName) },
        ...history.slice(-8).map((m) => ({ role: m.role, content: m.content })),
        { role: "user", content: message },
    ];
    const toolsUsed: string[] = [];

    for (let turn = 0; turn < MAX_TURNS; turn++) {
        const resp = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
            body: JSON.stringify({ model: MODEL, messages, tools: TOOLS, tool_choice: "auto", temperature: 0.3 }),
        });
        if (!resp.ok) throw new Error(`openai ${resp.status}: ${(await resp.text()).slice(0, 300)}`);
        const data: any = await resp.json();
        const msg = data.choices?.[0]?.message;
        if (!msg) throw new Error("no choice from openai");

        if (msg.tool_calls?.length) {
            messages.push(msg);
            for (const tc of msg.tool_calls) {
                const args = safeParse(tc.function.arguments);
                toolsUsed.push(tc.function.name);
                const result = await exec(tc.function.name, args);
                messages.push({ role: "tool", tool_call_id: tc.id, name: tc.function.name, content: JSON.stringify(result) });
            }
            continue;
        }
        return { reply: (msg.content || "").trim(), toolsUsed: [...new Set(toolsUsed)] };
    }
    return { reply: "Sorry — I got tangled up working that out. Try asking a slightly simpler question.", toolsUsed: [...new Set(toolsUsed)] };
}

function safeParse(s: string): any { try { return JSON.parse(s || "{}"); } catch { return {}; } }
