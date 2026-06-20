/**
 * ElevenLabs voice I/O for the conversational Plan-my-day flow.
 * STT (scribe) turns the presenter's spoken sentence into text; TTS (turbo) speaks the
 * money verdict back. Both are thin fetch wrappers — same style as openaiChat.ts (no SDK).
 */
const STT_MODEL = process.env.ELEVENLABS_STT_MODEL || "scribe_v1";
const TTS_MODEL = process.env.ELEVENLABS_TTS_MODEL || "eleven_turbo_v2_5";
// Default voice = "Rachel" (a calm, clear ElevenLabs preset); override per-deploy if desired.
const VOICE_ID = process.env.ELEVENLABS_VOICE_ID || "21m00Tcm4TlvDq8ikWAM";

function apiKey(): string {
    const key = process.env.ELEVENLABS_API_KEY;
    if (!key) throw Object.assign(new Error("voice not configured (no ELEVENLABS_API_KEY)"), { code: 503 });
    return key;
}

/** Spoken audio → transcript. `mime` describes the recording (e.g. audio/m4a). */
export async function transcribe(audio: Buffer, mime: string): Promise<string> {
    const form = new FormData();
    form.append("model_id", STT_MODEL);
    form.append("file", new Blob([new Uint8Array(audio)], { type: mime || "audio/m4a" }), "audio.m4a");
    const resp = await fetch("https://api.elevenlabs.io/v1/speech-to-text", {
        method: "POST",
        headers: { "xi-api-key": apiKey() },
        body: form,
    });
    if (!resp.ok) throw new Error(`elevenlabs stt ${resp.status}: ${(await resp.text()).slice(0, 300)}`);
    const data: any = await resp.json();
    return String(data.text || "").trim();
}

/** Verdict text → mp3 bytes (low-latency turbo model). */
export async function synthesize(text: string): Promise<Buffer> {
    const resp = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}`, {
        method: "POST",
        headers: { "xi-api-key": apiKey(), "Content-Type": "application/json", Accept: "audio/mpeg" },
        body: JSON.stringify({
            text,
            model_id: TTS_MODEL,
            voice_settings: { stability: 0.4, similarity_boost: 0.75 },
        }),
    });
    if (!resp.ok) throw new Error(`elevenlabs tts ${resp.status}: ${(await resp.text()).slice(0, 300)}`);
    return Buffer.from(await resp.arrayBuffer());
}
