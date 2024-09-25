import type { ConfigDataDynamic } from "@/server/configDynamic";
import type { ClassId } from "./wow";

type ErrorRes = {
    error: string;
};

type AuthRes = {
    loginId: string;
    loginToken: string;
};

type AuthUserRes = {
    loginValid: boolean;
    userName: string;
    permissions: number;
};

type AuditEntry = {
    id: number;
    timestamp: number;
    loginId: string;
    userName: string;
    eventInfo: string;
};

type PagedRes<T> = {
    pageOffset: number;
    haveMore: boolean;
    entries: T[];
};

type AuditRes = PagedRes<AuditEntry>;

type UserEntry = {
    loginId: string;
    userName: string;
    permissions: number;
    lastActivity: number;
};

type UserRes = UserEntry[];

type DeleteRes = {
    success: boolean;
    error?: string;
};

type UpdateRes = {
    success: boolean;
    error?: string;
};

type PlayerEntry = {
    playerName: string;
    classId: ClassId;
    points: number;
    account?: string;
};

type PointChangeType = "ITEM_AWARD" | "ITEM_AWARD_REVERTED" | "PLAYER_ADDED" | "CUSTOM" | "READY" | "RAID" | "DECAY";

type ApiPointChangeRequest = {
    reason: string;
    change: number;
};

type ApiPointChangeResult = {
    success: boolean;
    error?: string;
    change: number;
    newPoints: number;
};

type PointHistoryEntry = {
    id: number;
    timestamp: number;
    playerName: string;
    pointChange: number;
    newPoints: number;
    changeType: PointChangeType;
    reason?: string;
};

type PointHistoryPageRes = PagedRes<PointHistoryEntry>;

type PointHistorySearchInput = {
    playerName?: string;
    timeStart?: number;
    timeEnd?: number;
};

type LootHistoryEntry = {
    id: number;
    guid: string;
    timestamp: number;
    playerName: string;
    itemId: number;
    response: string;
};

type ApiProfileResult = {
    player: PlayerEntry;
    pointHistory: PointHistoryEntry[];
    lootHistory: LootHistoryEntry[];
};

type LootHistoryPageRes = PagedRes<LootHistoryEntry>;

type LootHistorySearchInput = {
    playerName?: string;
    timeStart?: number;
    timeEnd?: number;
    response?: string;
};

type ItemData = {
    itemId: number;
    itemName: string;
    qualityId: number;
    iconName: string;
};

type AddonPointHistoryEntry = {
    timeStamp: number; // Unix timestamp
    playerName: string;
    change: number;
    newPoints: number;
    type: PointChangeType;
    reason?: string; // Misc data for type.
};

type AddonPlayerEntry = {
    playerName: string;
    classId: number;
    points: number;
};

type AddonLootHistoryEntry = {
    guid: string; // Unique identifier for this loot distribution.
    timeStamp: number; // Unix timestamp of the award time.
    playerName: string; // The player the item was awarded to.
    itemId: number;
    response: string; // The response / award reason in the format {id,rgb_hexcolor}displayString
};

type AddonExport = {
    time: number;
    minTimestamp: number;
    players: AddonPlayerEntry[];
    pointHistory: AddonPointHistoryEntry[];
    lootHistory: AddonLootHistoryEntry[];
};

type ImportLog = {
    players: {
        new: AddonPlayerEntry;
        old?: PlayerEntry;
    }[];
    lootHistory: {
        // make obj so it's easy to change later if needed
        new: AddonLootHistoryEntry;
    }[];
    pointHistory: {
        // make obj so it's easy to change later if needed
        new: AddonPointHistoryEntry;
    }[];
};

type ApiImportResult = {
    error?: string;
    log?: ImportLog;
};

type ApiImportLogEntry = {
    id: number;
    timestamp: number;
    user: string;
    logData: string;
    userName: string;
};

type ApiImportLogListResult = {
    logs: ApiImportLogEntry[];
};

type ApiExportResult = {
    export: string;
};

type ApiSettingRes = ConfigDataDynamic;

type ApiSetSettingReq = {
    changes: { key: string; value: unknown }[];
};
