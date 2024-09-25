export const enum AccPermissions {
    NONE = 0,
    AUDIT_VIEW = 0x1,
    USERS_VIEW = 0x8,
    USERS_MANAGE = 0x10,
    DATA_VIEW = 0x20,
    DATA_MANAGE = 0x40,
    DATA_DELETE = 0x80,
    SETTINGS_VIEW = 0x10000000,
    SETTINGS_EDIT = 0x20000000,
    ADMIN = 0x40000000, // bit 31
    ALL = 0x7fffffff, // 32th bit would need |0 for every check :/
}

export const permissionData: Record<AccPermissions, { name: string; value: AccPermissions; noUi?: boolean }> = {
    [AccPermissions.NONE]: { name: "", value: AccPermissions.NONE, noUi: true },
    [AccPermissions.ALL]: { name: "", value: AccPermissions.ALL, noUi: true },

    [AccPermissions.AUDIT_VIEW]: { name: "Audit-view", value: AccPermissions.AUDIT_VIEW },
    [AccPermissions.USERS_VIEW]: { name: "Users-view", value: AccPermissions.USERS_VIEW },
    [AccPermissions.USERS_MANAGE]: { name: "Users-manage", value: AccPermissions.USERS_MANAGE },
    [AccPermissions.DATA_VIEW]: { name: "Data-view", value: AccPermissions.DATA_VIEW },
    [AccPermissions.DATA_MANAGE]: { name: "Data-manage", value: AccPermissions.DATA_MANAGE },
    [AccPermissions.DATA_DELETE]: { name: "Data-delete", value: AccPermissions.DATA_DELETE },
    [AccPermissions.SETTINGS_VIEW]: { name: "Settings-view", value: AccPermissions.SETTINGS_VIEW },
    [AccPermissions.SETTINGS_EDIT]: { name: "Settings-edit", value: AccPermissions.SETTINGS_EDIT },
    [AccPermissions.ADMIN]: { name: "Admin", value: AccPermissions.ADMIN },
};

/**
 * Get array of names for all permissions in the given mask.
 * @param perms
 * @returns
 */
export const getPermissionStrings = (perms: AccPermissions): string[] => {
    const strs: string[] = [];
    for (let i = 0; i < 32; i++) {
        const bitVal = (1 << i) as AccPermissions;
        if ((bitVal & perms) !== 0) {
            if (permissionData[bitVal] && !permissionData[bitVal].noUi) strs.push(permissionData[bitVal].name);
        }
    }
    return strs;
};
