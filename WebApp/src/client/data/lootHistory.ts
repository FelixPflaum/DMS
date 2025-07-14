import type { LootHistoryRow } from "@/server/database/types";
import { apiGet } from "../serverApi";
import type { ApiLootHistorySearchRes } from "@/shared/types";

const cache = new Map<string, LootHistoryRow>();
let guidsToLoad: string[] = [];
let loadPromise: { prom: Promise<void>; res: () => void } | undefined;
let lastError: Error | undefined;

async function loadData() {
    if (!guidsToLoad || guidsToLoad.length === 0) return;
    const res = await apiGet<ApiLootHistorySearchRes>(`/api/loothistory/entries/${guidsToLoad.join(",")}`);
    guidsToLoad = [];

    if (res.error) {
        console.error(res.error);
        lastError = new Error(res.error);
        return;
    }

    for (const row of res.results) {
        cache.set(row.guid, row);
    }

    if (loadPromise) {
        loadPromise.res();
        loadPromise = undefined;
    }
}

function queueLoadRow(guid: string): Promise<void> {
    guidsToLoad.push(guid);
    if (loadPromise) return loadPromise.prom;
    setTimeout(loadData, 250);
    let res: () => void;
    const prom = new Promise<void>((_res) => (res = _res));
    loadPromise = { prom: prom, res: res! };
    return loadPromise.prom;
}

/**
 * Get loot history entry by guid. Caches entries and loads from API in batches if called rapidly.
 * @param guid The guid of the history entry.
 * @returns
 */
export const getLootHistoryEntry = async (guid: string): Promise<LootHistoryRow | undefined> => {
    const existing = cache.get(guid);
    if (existing) return existing;

    await queueLoadRow(guid);
    if (lastError) throw lastError;

    return cache.get(guid);
};

/**
 * Clear cached data.
 */
export function clearLootHistoryCache(): void {
    cache.clear();
}
