import type { PoolConnection } from "mysql2/promise";
import { querySelect } from "./database/database";
import { getSetting, setSetting } from "./database/tableFunctions/settings";
import type { SettingsRow } from "./database/types";
import { Logger } from "./Logger";

export type ConfigDataDynamic = {
    decayMult: number;
    nextAutoDecay: number;
    autoDecayDay: number;
    autoDecayHour: number;
    discordAllowedRoles: string[];
};

const logger = new Logger("DynSettings");

const defaults: ConfigDataDynamic = {
    decayMult: 0.9,
    nextAutoDecay: 0,
    autoDecayDay: 3,
    autoDecayHour: 4,
    discordAllowedRoles: ["Admin", "Test123"],
};

const callbacks: Partial<Record<keyof ConfigDataDynamic, (() => void)[]>> = {};

/**
 * Init all dynamic settings, setting them to their default value if they do not exist in the DB.
 * @returns true if success, false if an error occured.
 */
export const initSettings = async (): Promise<boolean> => {
    let settingKey: keyof ConfigDataDynamic;
    for (settingKey in defaults) {
        const dbRes = await getSetting(settingKey);
        if (dbRes.isError) return false;
        if (!dbRes.row) {
            console.log("Init dynamic setting " + settingKey + " to " + JSON.stringify(defaults[settingKey]));
            const setRes = await setSetting(settingKey, JSON.stringify(defaults[settingKey]));
            if (setRes.isError) return false;
        }
    }
    return true;
};

/**
 * Check if value matches the setting value type for key.
 * @param key
 * @param value
 * @returns
 */
export const checkValueType = <T extends keyof ConfigDataDynamic>(key: T, value: unknown): value is ConfigDataDynamic[T] => {
    if (Array.isArray(defaults[key])) {
        if (!Array.isArray(value)) return false;
        const elemType = typeof defaults[key][0];
        for (const v of value) {
            if (typeof v !== elemType) return false;
        }
        return true;
    }
    return typeof value === typeof defaults[key];
};

/**
 * Check if key is valid settings key.
 * @param key
 * @param value
 * @returns
 */
export const isDynamicSettingKey = (key: unknown): key is keyof ConfigDataDynamic => {
    if (typeof key !== "string") return false;
    // @ts-ignore
    return key in defaults;
};

/**
 * Get dynamic setting from DB. This is just a wrapper around getSetting() that handles types.
 * @param key
 * @returns
 */
export const getDynamicSetting = async <T extends keyof ConfigDataDynamic>(
    key: T
): Promise<{ value?: ConfigDataDynamic[T]; dbError?: boolean }> => {
    const dbRes = await getSetting(key);
    const ret: { value?: ConfigDataDynamic[T]; dbError?: boolean } = {};
    if (dbRes.isError) {
        ret.dbError = true;
    } else if (dbRes.row) {
        ret.value = JSON.parse(dbRes.row.svalue);
    }
    return ret;
};

/**
 * Get all current dynamic settings.
 * @returns
 */
export const getDynamicSettings = async (): Promise<{ data?: ConfigDataDynamic; dbError?: boolean }> => {
    const keys = Object.keys(defaults)
        .map((v) => `'${v}'`)
        .join(",");

    const dbRes = await querySelect<SettingsRow>(`SELECT * FROM settings WHERE skey IN (${keys});`);
    if (dbRes.isError) return { dbError: true };

    const dbSettings: Record<string, unknown> = {};
    for (const r of dbRes.rows) {
        dbSettings[r.skey] = JSON.parse(r.svalue);
    }
    let defKey: keyof ConfigDataDynamic;
    for (defKey in defaults) {
        if (!checkValueType(defKey, dbSettings[defKey])) {
            logger.logError("Missing dyn setting in DB! Key: " + defKey);
            return {};
        }
    }
    return { data: dbSettings as ConfigDataDynamic };
};

/**
 * Set dynamic setting in DB. This is just a wrapper around setSetting() that handles types.
 * @param key
 * @param vlaue
 * @returns true if successful, false if DB error ocured.
 */
export const setDynamicSetting = async <T extends keyof ConfigDataDynamic>(
    key: T,
    vlaue: ConfigDataDynamic[T],
    conn?: PoolConnection
): Promise<boolean> => {
    const dbRes = await setSetting(key, JSON.stringify(vlaue), conn);
    if (dbRes.isError) return false;
    if (callbacks[key]) {
        for (const cb of callbacks[key]) cb();
    }
    return true;
};

export const onDynamicSettingChange = (key: keyof ConfigDataDynamic, callback: () => void): void => {
    if (!callbacks[key]) callbacks[key] = [];
    callbacks[key].push(callback);
};
