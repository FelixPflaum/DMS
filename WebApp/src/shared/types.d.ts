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

type AuditRes = {
    pageOffset: number;
    haveMore: boolean;
    entries: AuditEntry[];
};

type UserEntry = {
    loginId: string;
    userName: string;
    permissions: number;
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

type PointHistoryEntry = {
    id: number;
    timestamp: string;
    playerName: string;
    pointChange: number;
    newPoints: number;
    changeType: string;
    reason?: string;
};

type LootHistoryEntry = {
    id: number;
    guid: string;
    timestamp: string;
    playerName: string;
    itemId: number;
    response: string;
    reverted: number;
};
