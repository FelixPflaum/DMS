import type { ConfigDataDynamic } from "@/server/configDynamic";
import type { ClassId } from "./wow";

type ApiUserEntry = {
    loginId: string;
    userName: string;
    permissions: number;
    lastActivity: number;
};

type ApiAuditEntry = {
    id: number;
    timestamp: number;
    loginId: string;
    userName: string;
    eventInfo: string;
};

type ApiPlayerEntry = {
    playerName: string;
    classId: ClassId;
    points: number;
    account?: string;
};

type ApiPointHistoryEntry = {
    guid: string;
    timestamp: number;
    playerName: string;
    pointChange: number;
    newPoints: number;
    changeType: PointChangeType;
    reason?: string;
};

type ApiLootHistoryEntry = {
    guid: string;
    timestamp: number;
    playerName: string;
    itemId: number;
    response: string;
};

type ApiItemEntry = {
    itemId: number;
    itemName: string;
    qualityId: number;
    iconName: string;
    iconId: number;
};

type ApiResponse = {
    error?: string;
};

type ApiAuthRes = ApiResponse & {
    loginId: string;
    loginToken: string;
};

type ApiAuthUserRes = ApiResponse & {
    invalidLogin: boolean;
    user: ApiUserEntry;
};

type PagedRes<T> = ApiResponse & {
    pageOffset: number;
    haveMore: boolean;
    entries: T[];
};

type ApiAuditPageRes = PagedRes<ApiAuditEntry>;

type ApiUserRes = ApiResponse & {
    user: ApiUserEntry;
};

type ApiUserListRes = ApiResponse & {
    list: ApiUserEntry[];
};

type PointChangeType = "ITEM_AWARD" | "ITEM_AWARD_REVERTED" | "PLAYER_ADDED" | "CUSTOM" | "READY" | "RAID" | "DECAY";

type ApiPointChangeRequest = {
    playerName: string;
    reason: string;
    change: number;
};

type ApiPointChangeResult = ApiResponse & {
    playerName: string;
    change: number;
    newPoints: number;
};

type ApiPointHistoryPageRes = PagedRes<ApiPointHistoryEntry>;

type ApiPointHistorySearchInput = {
    playerName?: string;
    searchName?: string;
    timeStart?: number;
    timeEnd?: number;
};

type ApiPointHistorySearchRes = ApiResponse & {
    list: ApiPointHistoryEntry[];
};

type ApiProfileResult = ApiResponse & {
    player: ApiPlayerEntry;
    pointHistory: ApiPointHistoryEntry[];
    lootHistory: ApiLootHistoryEntry[];
};

type ApiLootHistoryPageRes = PagedRes<ApiLootHistoryEntry>;

type LootHistorySearchInput = {
    playerName?: string;
    searchName?: string;
    timeStart?: number;
    timeEnd?: number;
    response?: string;
};

type ApiLootHistorySearchRes = ApiResponse & {
    results: ApiLootHistoryEntry[];
};

type AddonPointHistoryEntry = {
    guid: string;
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
        old?: ApiPlayerEntry;
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

type ApiImportResult = ApiResponse & {
    log: ImportLog;
};

type ApiImportLogEntry = {
    id: number;
    timestamp: number;
    user: string;
    logData: string;
    userName: string;
};

type ApiImportLogListResult = ApiResponse & {
    logs: ApiImportLogEntry[];
};

type ApiImportLogRes = ApiResponse & {
    entry: ApiImportLogEntry;
};

type ApiExportResult = ApiResponse & {
    export: string;
};

type ApiDynSettings = ConfigDataDynamic;

type ApiSettingRes = ApiResponse & {
    settings: ApiDynSettings;
};

type ApiSetSettingReq = {
    changes: { key: string; value: unknown }[];
};

type ApiBackupListRes = ApiResponse & {
    list: string[];
};

type ApiMakeBackupRes = ApiResponse & { file: string };

type ApiItemListRes = ApiResponse & {
    list: ApiItemEntry[];
};

type ApiPlayerRes = ApiResponse & {
    player: ApiPlayerEntry;
};

type ApiPlayerListRes = ApiResponse & {
    list: ApiPlayerEntry[];
};

type ApiSelfPlayerRes = ApiResponse & {
    myChars: ApiPlayerEntry[];
};
