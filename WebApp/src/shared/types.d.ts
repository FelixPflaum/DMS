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

type UserDeleteRes = {
    success: boolean;
    error?: string;
};

type UserUpdateRes = {
    success: boolean;
    error?: string;
};
