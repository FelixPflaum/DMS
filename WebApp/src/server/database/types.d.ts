type UserRow = {
    loginId: string;
    loginToken: string;
    userName: string;
    validUntil: number;
    permissions: number;
};

type AuditRow = {
    id: number;
    timestamp: number;
    loginId: string;
    userName: string;
    eventInfo: string;
};

type SettingsRow = {
    skey: string;
    svalue: string;
};
