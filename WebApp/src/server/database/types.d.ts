import type { ClassId } from "@/client/typings/wow";

type UserRow = {
    loginId: string;
    loginToken: string;
    userName: string;
    validUntil: number;
    permissions: number;
};

type AuditRow = {
    id: number;
    timestamp: string;
    loginId: string;
    userName: string;
    eventInfo: string;
};

type SettingsRow = {
    skey: string;
    svalue: string;
};

type ItemDataRow = {
    itemId: number;
    itemName: string;
    qualityId: number;
};

type PlayerRow = {
    playerName: string;
    classId: ClassId;
    points: number;
    account?: string;
};

type PointHistoryRow = {
    id: number;
    timestamp: string;
    playerName: string;
    pointChange: number;
    newPoints: number;
    changeType: string;
    reason?: string;
};

type LootHistoryRow = {
    id: number;
    guid: string;
    timestamp: string;
    playerName: string;
    itemId: number;
    response: string;
    reverted: number;
};
