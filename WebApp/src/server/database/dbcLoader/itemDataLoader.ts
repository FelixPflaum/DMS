import { readDBCSVtoMap } from "./dbcReader";
import { Logger } from "@/server/Logger";
import { queryDb } from "../database";
import type { ItemDataRow } from "../types";
import { getSetting, setSetting } from "../tableFunctions/settings";
import { getAllItems } from "../tableFunctions/itemData";

const url = "https://wago.tools/db2/ItemSparse/csv?branch=wow_classic_era";

async function getCurrentBuild() {
    const res = await fetch(url, { method: "HEAD" });
    const disp = res.headers.get("content-disposition");
    if (!disp) return false;
    const buildMatch = disp.match(/filename=".*?\.(\d+)\.csv/);
    if (!buildMatch) return false;
    const build = parseInt(buildMatch[1]);
    if (!build) return false;
    return build;
}

async function update(logger: Logger) {
    logger.log("Getting current build number...");
    const currentBuild = await getCurrentBuild();
    if (!currentBuild) {
        logger.logError("Can't get build for itemsparse file, canceling.");
        return;
    }
    logger.log("Current build is " + currentBuild);

    const settingResult = await getSetting("itemDbVersion");
    if (settingResult.isError) {
        logger.logError("Getting setting from DB failed.");
        process.exit(1);
    }
    if (settingResult.row && parseInt(settingResult.row.svalue) >= currentBuild) {
        logger.log("Build is up to date.");
        return;
    }
    logger.log("Installed build is " + (settingResult.row?.svalue ?? "none"));

    const res = await fetch(url);
    if (res.status !== 200) {
        logger.logError("Could not download item data file.");
        return;
    }

    const csv = await res.text();
    const csvMap = readDBCSVtoMap<{ ID: number; Display_lang: string; OverallQualityID: number }>(csv, "ID");

    const dbItemsRes = await getAllItems();
    if (dbItemsRes.isError) {
        logger.logError("Getting items from DB failed.");
        process.exit(1);
    }

    logger.log(`Have ${csvMap.size} items from file.`);
    logger.log(`Have ${dbItemsRes.rows.length} items from DB.`);

    const itemsToInsert: ItemDataRow[] = [];
    const itemsToUpdate: ItemDataRow[] = [];

    for (const newItem of csvMap.values()) {
        if (!newItem.Display_lang) continue;
        let found = false;
        for (const oldItem of dbItemsRes.rows) {
            if (oldItem.itemId == newItem.ID) {
                found = true;
                if (oldItem.itemName != newItem.Display_lang || oldItem.qualityId != newItem.OverallQualityID) {
                    itemsToUpdate.push({
                        itemId: newItem.ID,
                        itemName: newItem.Display_lang,
                        qualityId: newItem.OverallQualityID,
                    });
                }
                break;
            }
        }
        if (!found)
            itemsToInsert.push({
                itemId: newItem.ID,
                itemName: newItem.Display_lang,
                qualityId: newItem.OverallQualityID,
            });
    }

    logger.log(`Need to insert ${itemsToInsert.length} items and update ${itemsToUpdate.length} items...`);

    let count = 0;
    for (const iti of itemsToInsert) {
        count++;
        await queryDb(`INSERT INTO itemData (itemId, itemName, qualityId) VALUES (?, ?, ?);`, [
            iti.itemId,
            iti.itemName,
            iti.qualityId,
        ]);
        if (count % 20 == 0) logger.log(`Inserted ${count} of ${itemsToInsert.length} items.`);
    }
    count = 0;
    for (const itu of itemsToUpdate) {
        count++;
        await queryDb(`UPDATE itemData SET itemName=?, qualityId=? WHERE itemId=?;`, [
            itu.itemName,
            itu.qualityId,
            itu.itemId,
        ]);
        if (count % 20 == 0) logger.log(`Updated ${count} of ${itemsToUpdate.length} items.`);
    }

    const setRes = await setSetting("itemDbVersion", currentBuild.toString());
    if (setRes.isError) {
        logger.logError("Could not update itemDbVersion settings value to " + currentBuild);
        process.exit(1);
    }
}

export const checkAndUpdateItemDb = async (): Promise<void> => {
    const logger = new Logger("Item DB");

    const settingLastUpdateRes = await getSetting("itemDbLastCheck");
    if (settingLastUpdateRes.isError) {
        logger.logError("Getting setting itemDbLastCheck from DB failed.");
        process.exit(1);
    }

    const lastUpdate = settingLastUpdateRes.row ? parseInt(settingLastUpdateRes.row.svalue) : 0;
    const now = Date.now();
    if (now - lastUpdate < 3600 * 1000) {
        logger.log("Last update check recent, skipping.");
        setSetting("itemDbLastCheck", Date.now().toString());
        return;
    }

    await update(logger);

    const setLastRes = await setSetting("itemDbLastCheck", Date.now().toString());
    if (setLastRes.isError) {
        logger.logError("Could not update itemDbLastCheck settings value to " + Date.now());
        process.exit(1);
    }

    logger.log("Item DB updated!");
};
