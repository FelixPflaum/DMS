import { generateGuid } from "@/shared/guid";
import { getDynamicSetting, onDynamicSettingChange, setDynamicSetting } from "../configDynamic";
import { getConnection } from "../database/database";
import { addSystemAuditEntry } from "../database/tableFunctions/audit";
import { getAllPlayers, updatePlayer } from "../database/tableFunctions/players";
import { createPointHistoryEntry } from "../database/tableFunctions/pointHistory";
import { makeDataBackup } from "../importExport/backup";
import { Logger } from "../Logger";

const logger = new Logger("Decay");

async function applyDecay(mult: number, rescheduleNext = 0): Promise<boolean> {
    const conn = await getConnection();
    const now = Date.now();
    const decayPctString = ((1 - mult) * 100).toFixed(1) + "% Decay";

    const rollbackThenFalse = async () => {
        await conn.rollback();
        return false;
    };

    try {
        conn.query("LOCK TABLES players WRITE, pointHistory WRITE;");
        conn.beginTransaction();

        const backupSuccess = await makeDataBackup(conn, 0, "before_decay");
        if (!backupSuccess) {
            logger.logError("Making data backup before decay commit failed!");
            return rollbackThenFalse();
        }

        const playersRes = await getAllPlayers(conn);
        if (playersRes.isError) throw new Error();

        for (const player of playersRes.rows) {
            const newPoints = Math.floor(player.points * mult);
            const change = newPoints - player.points;

            if (change >= 0) continue;

            const updRes = await updatePlayer(player.playerName, { points: newPoints }, conn);
            if (updRes.isError) return rollbackThenFalse();

            const pointRes = await createPointHistoryEntry(
                {
                    guid: generateGuid(),
                    timestamp: now,
                    playerName: player.playerName,
                    pointChange: change,
                    newPoints: newPoints,
                    changeType: "DECAY",
                    reason: `${decayPctString}`,
                },
                conn
            );
            if (pointRes.isError) return rollbackThenFalse();
        }

        if (rescheduleNext) {
            const success = setDynamicSetting("nextAutoDecay", rescheduleNext);
            if (!success) return rollbackThenFalse();
        }

        await conn.commit();
        return true;
    } catch (error) {
        await conn.rollback();
        logger.logError("Error on DB applying decay.", error);
        return false;
    } finally {
        await conn.query("UNLOCK TABLES;");
        conn.release();
    }
}

let timer: NodeJS.Timeout;

async function checkDecay() {
    const nextAutoDecayRes = await getDynamicSetting("nextAutoDecay");
    const decayMultRes = await getDynamicSetting("decayMult");
    const autoDecayDayRes = await getDynamicSetting("autoDecayDay");
    const autoDecayHourRes = await getDynamicSetting("autoDecayHour");
    if (
        typeof nextAutoDecayRes.value !== "number" ||
        typeof decayMultRes.value !== "number" ||
        typeof autoDecayDayRes.value !== "number" ||
        typeof autoDecayHourRes.value !== "number"
    ) {
        logger.logError("Automatic decay check failed! Could not get setting from db.");
        return;
    }

    const timeToUpdate = nextAutoDecayRes.value - Date.now();

    if (timeToUpdate <= 0) {
        logger.log("Starting automatic decay application...");

        const nextTargetTime = new Date();
        const distToNextTargetDay = 7 - ((nextTargetTime.getDay() + autoDecayDayRes.value + 1) % 7);
        nextTargetTime.setDate(nextTargetTime.getDate() + distToNextTargetDay);
        nextTargetTime.setHours(autoDecayHourRes.value);
        nextTargetTime.setMinutes(0);
        nextTargetTime.setSeconds(0);
        nextTargetTime.setMilliseconds(0);

        const success = await applyDecay(decayMultRes.value, nextTargetTime.getTime());
        if (success) {
            logger.log("Automatic decay successful!");
            await addSystemAuditEntry("Applied Automatic Decay", `Multi: ${decayMultRes.value}. Backup created.`);
        } else {
            logger.logError("Failed on decay application! Retry in an hour.");
            setTimeout(checkDecay, 3600000);
            return;
        }
    } else {
        const tar = new Date(Date.now() + timeToUpdate);
        logger.log("Automatic decay not due. Set timer for " + tar.toLocaleString());
        timer = setTimeout(checkDecay, timeToUpdate + 10);
    }
}

/**
 * Start automatic decay timer and do a check now.
 * @returns
 */
export const startDecayCheck = (): void => {
    if (timer) clearTimeout(timer);
    checkDecay();
};

onDynamicSettingChange("nextAutoDecay", () => startDecayCheck());
