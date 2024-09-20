export const enum AccPermissions {
    NONE = 0,
    AUDIT_VIEW = 0x1,
    USERS_VIEW = 0x8,
    USERS_MANAGE = 0x10,
    ALL = 0x7fffffff, // 32th bit would need |0 for every check :/
}
