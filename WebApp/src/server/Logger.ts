import * as fs from "fs";

const LOG_FILE_NAME = "log.txt";

export class Logger {
    private static ws: fs.WriteStream | undefined;

    private readonly moduleName: string;

    constructor(moduleName?: string) {
        this.moduleName = moduleName || "";
    }

    private static getWriteStream() {
        if (!Logger.ws) Logger.ws = fs.createWriteStream(LOG_FILE_NAME, { flags: "a" });
        return Logger.ws;
    }

    private formatLogMessage(msg: string, isError = false) {
        const now = new Date();
        if (isError) return `[${now.toLocaleString()}][${this.moduleName}][ERROR]: ${msg}`;
        return `[${now.toLocaleString()}][${this.moduleName}]: ${msg}`;
    }

    private writeToStream(str: string) {
        Logger.getWriteStream().write(str);
    }

    log(msg: string): void {
        const logstr = this.formatLogMessage(msg);
        console.log(logstr);
        this.writeToStream(logstr + "\n");
    }

    logError(msg: string, error?: unknown): void {
        const logstr = this.formatLogMessage(msg, true);
        console.error(logstr);
        this.writeToStream(logstr + "\n");

        if (error) {
            if (error instanceof Error) {
                console.error(error);
                this.writeToStream(error.message + "\n");
                if (error.stack) this.writeToStream("Stacktrace: \n" + error.stack + "\n");
            } else {
                console.error(error);
                if (typeof error === "string") this.writeToStream(error + "\n");
                else if (error.toString) this.writeToStream(error.toString() + "\n");
                else this.writeToStream("Unknown error format!\n");
            }
        }
    }
}
