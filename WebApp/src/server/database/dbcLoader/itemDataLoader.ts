import { readDBCSVtoMap } from "./dbcReader";
import { Logger } from "@/server/Logger";
import { queryDb } from "../database";
import type { ItemDataRow } from "../types";
import { getSetting, setSetting } from "../tableFunctions/settings";
import { getAllItems } from "../tableFunctions/itemData";

const urlItem = "https://wago.tools/db2/Item/csv?branch=wow_classic_era";
const urlSparse = "https://wago.tools/db2/ItemSparse/csv?branch=wow_classic_era";
function getAtlasUrl(build: number): string {
    return `https://www.townlong-yak.com/framexml/${build}/Helix/ArtTextureID.lua`;
}

function getAtlasFromString(atlasStr: string, logger: Logger): Record<number, string> {
    const rgx = new RegExp(`(\\d+)</span>]=<span.+Interface.+/(.+)"</span>`);
    const lines = atlasStr.split("\n");
    const atlas: Record<number, string> = {};
    logger.log("Generating atlas...");
    let count = 0;
    for (const line of lines) {
        const match = line.match(rgx);
        if (match) {
            atlas[match[1] as unknown as number] = match[2];
            count++;
        }
    }
    logger.log("Generated " + count + " atlas entries.");
    return atlas;
}

async function getCurrentBuild() {
    const res = await fetch(urlSparse, { method: "HEAD" });
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

    logger.log("Gettings ItemSparse data");
    const sparseRes = await fetch(urlSparse);
    if (sparseRes.status !== 200) {
        logger.logError("Could not download ItemSparse data file.");
        return;
    }

    logger.log("Gettings Item data");
    const itemRes = await fetch(urlItem);
    if (itemRes.status !== 200) {
        logger.logError("Could not download Item data file.");
        return;
    }

    logger.log("Gettings atlas data");
    const atlasRes = await fetch(getAtlasUrl(currentBuild));
    if (itemRes.status !== 200) {
        logger.logError("Could not download atlas data file.");
        return;
    }
    const atlas = getAtlasFromString(await atlasRes.text(), logger);

    const csvItem = await itemRes.text();
    const csvMapItem = readDBCSVtoMap<{ ID: number; IconFileDataID: number }>(csvItem, "ID");

    const csvSparse = await sparseRes.text();
    const csvMapItemSparse = readDBCSVtoMap<{ ID: number; Display_lang: string; OverallQualityID: number }>(csvSparse, "ID");

    const dbItemsRes = await getAllItems();
    if (dbItemsRes.isError) {
        logger.logError("Getting items from DB failed.");
        process.exit(1);
    }

    logger.log(`Have ${csvMapItemSparse.size} items from file.`);
    logger.log(`Have ${dbItemsRes.rows.length} items from DB.`);

    const itemsToInsert: ItemDataRow[] = [];
    const itemsToUpdate: ItemDataRow[] = [];

    for (const newItemSparse of csvMapItemSparse.values()) {
        if (!newItemSparse.Display_lang) continue;

        const itemData = csvMapItem.get(newItemSparse.ID);
        if (!itemData) throw new Error("Item data for item missing! " + newItemSparse.ID);

        const itemIconName = itemData.IconFileDataID > 0 ? atlas[itemData.IconFileDataID] : "";
        if (typeof itemIconName === "undefined")
            throw new Error(`Item icon ${itemData.IconFileDataID} not in atlas! ` + newItemSparse.ID);

        let found = false;
        for (const oldItem of dbItemsRes.rows) {
            if (oldItem.itemId == newItemSparse.ID) {
                found = true;
                if (
                    oldItem.itemName != newItemSparse.Display_lang ||
                    oldItem.qualityId != newItemSparse.OverallQualityID ||
                    oldItem.iconName != itemIconName
                ) {
                    itemsToUpdate.push({
                        itemId: newItemSparse.ID,
                        itemName: newItemSparse.Display_lang,
                        qualityId: newItemSparse.OverallQualityID,
                        iconName: itemIconName,
                    });
                }
                break;
            }
        }
        if (!found)
            itemsToInsert.push({
                itemId: newItemSparse.ID,
                itemName: newItemSparse.Display_lang,
                qualityId: newItemSparse.OverallQualityID,
                iconName: itemIconName,
            });
    }

    logger.log(`Need to insert ${itemsToInsert.length} items and update ${itemsToUpdate.length} items...`);

    let count = 0;
    for (const iti of itemsToInsert) {
        count++;
        await queryDb(`INSERT INTO itemData (itemId, itemName, qualityId, iconName) VALUES (?, ?, ?, ?);`, [
            iti.itemId,
            iti.itemName,
            iti.qualityId,
            iti.iconName,
        ]);
        if (count % 100 == 0) logger.log(`Inserted ${count} of ${itemsToInsert.length} items.`);
    }
    count = 0;
    for (const itu of itemsToUpdate) {
        count++;
        await queryDb(`UPDATE itemData SET itemName=?, qualityId=?, iconName=? WHERE itemId=?;`, [
            itu.itemName,
            itu.qualityId,
            itu.iconName,
            itu.itemId,
        ]);
        if (count % 100 == 0) logger.log(`Updated ${count} of ${itemsToUpdate.length} items.`);
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
