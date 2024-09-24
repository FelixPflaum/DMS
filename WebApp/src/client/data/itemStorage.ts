import type { ItemData } from "@/shared/types";
import { apiGet } from "../serverApi";

// TODO: invalidate this on login if needed

let itemStorage: Record<number, ItemData> = {};
let wasLoaded = false;
let isLoadingPromise: Promise<boolean> | undefined;

function loadFromLocalStorage(): boolean {
    const data = window.localStorage.getItem("itemData");
    if (data) {
        itemStorage = JSON.parse(data) as Record<number, ItemData>;
        wasLoaded = true;
        return true;
    }
    return false;
}

/**
 * Check if item data is loaded.
 * @returns
 */
export const isItemDataLoaded = (): boolean => {
    return wasLoaded;
};

/**
 * Load item data from API.
 * @returns true if data was loaded successfully, false otherwise.
 */
export const loadItemData = async (): Promise<boolean> => {
    if (isLoadingPromise) return await isLoadingPromise;
    if (loadFromLocalStorage()) return true;

    let resolver: (value: boolean) => void;
    isLoadingPromise = new Promise((res) => {
        resolver = res;
    });

    const itemData = await apiGet<ItemData[]>("/api/items/all", "load item data");
    if (!itemData) {
        resolver!(false);
        return false;
    }

    for (const item of itemData) {
        itemStorage[item.itemId] = item;
    }

    wasLoaded = true;
    window.localStorage.setItem("itemData", JSON.stringify(itemStorage));
    resolver!(true);
    isLoadingPromise = undefined;
    return true;
};

/**
 * Get data for an item.
 * @param itemId
 * @returns
 */
export const getItemData = (itemId: number): ItemData | undefined => {
    return itemStorage[itemId];
};

/**
 * Get URL to item page.
 * @param itemId
 * @returns
 */
export const getItemInfoUrl = (itemId: number): string => {
    return "https://www.wowhead.com/classic/item=" + itemId;
};

/**
 * Get URL to item icon.
 * @param iconName
 * @returns
 */
export const getItemIconUrl = (iconName: string): string => {
    return `https://wow.zamimg.com/images/wow/icons/small/${iconName}.jpg`;
};
