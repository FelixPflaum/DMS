export const enum AccPermissions {
    NONE = 0,
    AUDIT_VIEW = 0x1,
    USERS_VIEW = 0x8,
    USERS_MANAGE = 0x10,
    DATA_VIEW = 0x20,
    DATA_MANAGE = 0x40,
    DATA_DELETE = 0x80,
    ADMIN = 0x40000000, // bit 31
    ALL = 0x7fffffff, // 32th bit would need |0 for every check :/
}
