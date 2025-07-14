/**
 * Generate string in the format <8B time as hex>-<7B random hex>
 */
export const generateGuid = (): string => {
    return `${Math.round(Date.now() / 1000).toString(16)}-${Math.round(Math.random() * 0xfffffff).toString(16)}`;
};

/**
 * Check if string has the format of a internal guid. See generateGuid().
 * @param str
 * @returns
 */
export const isGuid = (str: string): boolean => {
    if (str[8] != "-") return false;
    if (str.length != 16) return false;
    return true;
};
