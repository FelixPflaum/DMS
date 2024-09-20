import { readDBCSVtoMap } from "./dbcReader";
import { Logger } from "@/server/Logger";
import { itemDb, queryDb, settingsDb } from "../database";
import { ItemDataRow } from "../types";

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

export const checkAndUpdateItemDb = async (): Promise<void> => {
    const logger = new Logger("Item DB");

    logger.log("Getting current build number...");
    const currentBuild = await getCurrentBuild();
    if (!currentBuild) {
        logger.logError("Can't get build for itemsparse file, canceling.");
        return;
    }
    logger.log("Current build is " + currentBuild);

    const installedBuild = await settingsDb.get("itemDbVersion");
    if (installedBuild && parseInt(installedBuild.svalue) >= currentBuild) {
        logger.log("Build is up to date.");
        return;
    }
    logger.log("Installed build is " + (installedBuild?.svalue ?? "none"));

    const res = await fetch(url);
    if (res.status !== 200) {
        logger.logError("Could not download item data file.");
        return;
    }

    const csv = await res.text();
    const csvMap = readDBCSVtoMap<{ ID: number; Display_lang: string; OverallQualityID: number }>(csv, "ID");

    const dbItems = await itemDb.getAll();

    logger.log(`Have ${csvMap.size} items from file.`);
    logger.log(`Have ${dbItems.length} items from DB.`);

    const itemsToInsert: ItemDataRow[] = [];
    const itemsToUpdate: ItemDataRow[] = [];

    for (const newItem of csvMap.values()) {
        if (!newItem.Display_lang) continue;
        let found = false;
        for (const oldItem of dbItems) {
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

    await settingsDb.set("itemDbVersion", currentBuild.toString());

    logger.log("Item DB updated!");
};
