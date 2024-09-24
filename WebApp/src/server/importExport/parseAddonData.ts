import { inflateRaw } from "zlib";
import { checkAddonExport, getLastErrorReason } from "./structureChecker";
import type { AddonExport } from "@/shared/types";

const ADDON_EXPORT_PREFIX = "DMSAE";
const ADDON_EXPORT_SUFFIX = "END";

function inflate(buf: Buffer): Promise<string> {
    return new Promise((resolve, reject) => {
        inflateRaw(buf, (err, res) => {
            if (err) {
                reject(err);
                return;
            }
            resolve(res.toString());
        });
    });
}

/**
 * Parse addon export and return it if valid.
 * @param input
 * @returns
 */
export const parseAddonExport = async (input: unknown): Promise<{ error?: string; data?: AddonExport }> => {
    if (typeof input !== "string") return { error: "Input is not a string!" };
    if (!input.startsWith(ADDON_EXPORT_PREFIX) || !input.endsWith(ADDON_EXPORT_SUFFIX)) {
        return { error: "Export string is incomplete!" };
    }
    const base64 = input.substring(ADDON_EXPORT_PREFIX.length, input.length - ADDON_EXPORT_SUFFIX.length);
    const deflated = Buffer.from(base64, "base64");
    try {
        const json = await inflate(deflated);
        const data = JSON.parse(json);
        if (!checkAddonExport(data)) return { error: getLastErrorReason() };
        return { data };
    } catch (error) {
        let err = "Error on reading input data.";
        if (error instanceof Error) {
            err = error.message;
        }
        return { error: err };
    }
};
