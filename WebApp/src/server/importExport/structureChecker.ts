import type { AddonExport } from "../../shared/types";

type DataCheckDef = {
    type?: string;
    needsFields?: Record<string, DataCheckDef>;
    arrayItemDef?: DataCheckDef;
    optional?: boolean;
};

const playerItemDef: DataCheckDef = {
    needsFields: {
        playerName: { type: "string" },
        classId: { type: "number" },
        points: { type: "number" },
    },
};

const pointHistoryItemDef: DataCheckDef = {
    needsFields: {
        timeStamp: { type: "number" },
        playerName: { type: "string" },
        change: { type: "number" },
        newPoints: { type: "number" },
        type: { type: "string" },
        reason: { type: "string", optional: true },
    },
};

const lootHistoryItemDef: DataCheckDef = {
    needsFields: {
        guid: { type: "string" },
        timeStamp: { type: "number" },
        playerName: { type: "string" },
        itemId: { type: "number" },
        response: { type: "string" },
    },
};

const addonExportFieldData: DataCheckDef = {
    type: "record",
    needsFields: {
        players: { arrayItemDef: playerItemDef },
        pointHistory: { arrayItemDef: pointHistoryItemDef },
        lootHistory: { arrayItemDef: lootHistoryItemDef },
    },
};

function inputIsRecond(input: unknown): input is Record<string, unknown> {
    if (!input || typeof input !== "object") return false;
    for (const _k in input) {
        return true;
    }
    return false;
}

let lastErrorReason = "";

function setError(errStr: string): false {
    lastErrorReason = errStr;
    return false;
}

function checkData(dataPath: string, data: unknown, dataCheckDef: DataCheckDef): boolean {
    if (typeof data === "undefined" || data == null) {
        if (!dataCheckDef.optional) return setError(`Required field ${dataPath} is missing!`);
        return true;
    }

    if (dataCheckDef.needsFields) {
        if (!inputIsRecond(data)) {
            return setError(`${dataPath} is not a record!`);
        }
        for (const needKey in dataCheckDef.needsFields) {
            const childCheckDef = dataCheckDef.needsFields[needKey as keyof typeof dataCheckDef];
            return checkData(`${dataPath}.${needKey}`, data[needKey], childCheckDef);
        }
    } else if (dataCheckDef.arrayItemDef) {
        if (!Array.isArray(data)) {
            return setError(`${dataPath} is not an array!`);
        }
        for (let i = 0; i < data.length; i++) {
            return checkData(`${dataPath}[${i}]`, data[i], dataCheckDef.arrayItemDef);
        }
    } else if (dataCheckDef.type) {
        if (typeof data !== dataCheckDef.type) {
            return setError(`${dataPath} has wrong type! Expected ${dataCheckDef.type} but got ${typeof data}`);
        }
    }

    return true;
}

/**
 * Check if input is valid addon export.
 * You can get the error message for failed check with getLastErrorReason().
 * @param input
 * @returns
 */
export const checkAddonExport = (input: unknown): input is AddonExport => {
    return checkData("input", input, addonExportFieldData);
};

/**
 * Get error output of last checkAddonExport() call.
 * @returns
 */
export const getLastErrorReason = (): string => {
    return lastErrorReason;
};
