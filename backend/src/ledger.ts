/** In-memory committed-loads ledger (per the spec — no persistence needed for the demo). */
export interface Commitment {
    householdId: string;
    device: string;
    deviceName: string;
    startISO: string;
    startIdx: number;
    durationSlots: number;
    powerKw: number;
    source: string;
}

const ledger: Commitment[] = [];

export function commitmentsFor(householdId: string): Commitment[] {
    return ledger.filter((c) => c.householdId === householdId);
}
export function addCommitment(c: Commitment): Commitment {
    // one commitment per device per household for the demo — replace if re-scheduled
    const i = ledger.findIndex((x) => x.householdId === c.householdId && x.device === c.device);
    if (i >= 0) ledger.splice(i, 1);
    ledger.push(c);
    return c;
}
export function clearCommitments(householdId?: string): void {
    const keep = householdId ? ledger.filter((c) => c.householdId !== householdId) : [];
    ledger.length = 0;
    ledger.push(...keep);
}
