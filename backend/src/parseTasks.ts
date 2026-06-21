/**
 * Natural-language → structured tasks. One gpt-4o call turns a spoken sentence
 * ("car charged for tomorrow morning, and there's a load of washing") into the same
 * PlanTaskInput[] the day planner already eats. The LLM owns the words; planDay owns the math.
 * Constrained to the real device library and a strict JSON schema so it can't invent devices.
 */
import { devicesFor } from "./devices";
import { PlanTaskInput } from "./planDay";

const MODEL = process.env.OPENAI_MODEL || "gpt-4o";

const SCHEMA = {
    type: "object",
    additionalProperties: false,
    properties: {
        tasks: {
            type: "array",
            items: {
                type: "object",
                additionalProperties: false,
                properties: {
                    device: { type: "string", description: "device id, must be one of the allowed ids" },
                    deadline: { type: "string", description: "ISO 8601 'finish by' time, or empty string if none" },
                    target: { type: "integer", description: "EV charge target %, 50–100; 0 if not the car" },
                },
                required: ["device", "deadline", "target"],
            },
        },
        notes: {
            type: "array",
            description: "Short acknowledgements of context that is NOT a device task (e.g. guests arriving).",
            items: { type: "string" },
        },
    },
    required: ["tasks", "notes"],
};

function systemPrompt(householdId: string, nowISO: string): string {
    const devices = devicesFor(householdId)
        .map((d) => `- ${d.id} (${d.name})`)
        .join("\n");
    return [
        "You convert a household's spoken plan for the day into a structured task list.",
        `The current time ("now") is ${nowISO} (Europe/Berlin, ISO 8601).`,
        "Only these devices exist — map each chore to exactly one id, and ignore anything that is not one of them:",
        devices,
        "Rules:",
        '- "load of washing" → washing_machine; "dishes" → dishwasher; "dry the clothes" → dryer; "the car"/"EV"/"charge" → ev.',
        "- deadline: emit an ISO 8601 timestamp the run must FINISH by, derived from now. " +
            '"tomorrow morning" → next day 07:00; "by 8" / "before tonight" → today (or next day if already past). ' +
            "Use an empty string when no deadline is implied.",
        "- target: for the car, the charge target % (default 80 if unspecified). Use 0 for non-car devices.",
        '- Context that names NO device (e.g. "people coming over at 8", "it\'s a busy day") produces NO task. ' +
            'Instead add a SHORT note capturing it to `notes` (e.g. "Guests arriving at 8pm") so we can show we understood. ' +
            "A few words each, at most 3 notes; empty array when there's nothing noteworthy.",
        "- Never output a device id that is not in the list above. If nothing maps, return an empty tasks array.",
    ].join("\n");
}

export interface ParsedPlan { tasks: PlanTaskInput[]; notes: string[] }

export async function parseTasks(householdId: string, nowISO: string, text: string): Promise<ParsedPlan> {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) throw Object.assign(new Error("parser not configured (no OPENAI_API_KEY)"), { code: 503 });

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
        body: JSON.stringify({
            model: MODEL,
            temperature: 0,
            messages: [
                { role: "system", content: systemPrompt(householdId, nowISO) },
                { role: "user", content: text.slice(0, 1000) },
            ],
            response_format: {
                type: "json_schema",
                json_schema: { name: "plan_tasks", strict: true, schema: SCHEMA },
            },
        }),
    });
    if (!resp.ok) throw new Error(`openai ${resp.status}: ${(await resp.text()).slice(0, 300)}`);
    const data: any = await resp.json();
    const parsed = safeParse(data.choices?.[0]?.message?.content);

    const valid = new Set(devicesFor(householdId).map((d) => d.id));
    const raw: any[] = Array.isArray(parsed?.tasks) ? parsed.tasks : [];
    const tasks = raw
        .filter((t) => valid.has(t?.device))
        .map((t): PlanTaskInput => {
            const out: PlanTaskInput = { device: String(t.device) };
            if (t.deadline) out.deadline = String(t.deadline);
            if (t.device === "ev" && Number(t.target) >= 50) out.target = Math.min(100, Number(t.target));
            return out;
        });
    const notes: string[] = (Array.isArray(parsed?.notes) ? parsed.notes : [])
        .filter((n: any) => typeof n === "string" && n.trim())
        .map((n: string) => n.trim())
        .slice(0, 3);
    return { tasks, notes };
}

function safeParse(s: string): any { try { return JSON.parse(s || "{}"); } catch { return {}; } }
