import type { ClassId } from "@/client/typings/wow";
import type { PointChangeType } from "@/shared/types";

type UserRow = {
    loginId: string;
    loginToken: string;
    userName: string;
    validUntil: number;
    permissions: number;
    lastActivity: number;
};

type AuditRow = {
    id: number;
    timestamp: number;
    loginId: string;
    userName: string;
    event: string;
    info: string;
};

type SettingsRow = {
    skey: string;
    svalue: string;
};

type ItemDataRow = {
    itemId: number;
    itemName: string;
    qualityId: number;
    iconName: string;
    iconId: number;
};

type PlayerRow = {
    playerName: string;
    classId: ClassId;
    points: number;
    account?: string;
};

type PointHistoryRow = {
    guid: string;
    timestamp: number;
    playerName: string;
    pointChange: number;
    newPoints: number;
    changeType: PointChangeType;
    reason?: string;
};

type LootHistoryRow = {
    guid: string;
    timestamp: number;
    playerName: string;
    itemId: number;
    response: string;
};

type ImportLogsRow = {
    id: number;
    timestamp: number;
    user: string;
    logData: string;
};
