import type { Request } from "express";

export class SpamCheck {
    private readonly max: number;
    private readonly dur: number;
    private readonly updateInterval = 10000;
    private readonly reqHistory: Record<string, number[]> = {};

    /**
     * Create new SpamCheck instance to check for spammy requests.
     * @param maxRequests Max requests in timeframe.
     * @param inDurationMs Timeframe to check.
     * @param updateInterval How often to clean up old requests.
     */
    constructor(maxRequests: number, inDurationMs: number) {
        this.max = maxRequests;
        this.dur = inDurationMs;
        this.update();
    }

    private update = () => {
        const now = Date.now();
        for (const ip in this.reqHistory) {
            const entries = this.reqHistory[ip];
            let firstKeepPos = -1;
            for (let i = 0; i < entries.length; i++) {
                if (now - entries[i] < this.dur) {
                    firstKeepPos = i;
                    break;
                }
            }
            if (firstKeepPos === -1) {
                delete this.reqHistory[ip];
            } else if (firstKeepPos > 0) {
                this.reqHistory[ip] = entries.slice(firstKeepPos);
            }
        }
        setTimeout(this.update, this.updateInterval);
    };

    isSpam(req: Request): boolean {
        const ip = req.ip;
        if (!ip) return true;
        if (!this.reqHistory[ip]) this.reqHistory[ip] = [];
        this.reqHistory[ip].push(Date.now());
        return this.reqHistory[ip].length > this.max;
    }
}
