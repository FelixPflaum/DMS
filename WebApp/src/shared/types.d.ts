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

type PointHistoryEntry = {
    id: number;
    timestamp: number;
    playerName: string;
    pointChange: number;
    newPoints: number;
    changeType: string;
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
    reverted: number;
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
