import type { ApiItemEntry, ApiItemListRes } from "@/shared/types";
import { apiGet } from "../serverApi";

// TODO: make this not suck this much

type ItemStorage = {
    version: number;
    items: Record<number, ApiItemEntry>;
};

const itemStorage: ItemStorage = {
    items: {},
    version: 0,
};

let wasLoaded = false;
let isLoadingPromise: Promise<boolean> | undefined;

function loadFromLocalStorage(): boolean {
    const data = window.localStorage.getItem("itemData");
    if (data) {
        const ld = JSON.parse(data) as ItemStorage;
        itemStorage.items = ld.items;
        itemStorage.version = ld.version;
        wasLoaded = true;
        return true;
    }
    return false;
}
loadFromLocalStorage();

/**
 * Check if item data is loaded.
 * @param version If set only return true if data was loaded and its version is same or higher.
 * @returns
 */
export const isItemDataLoaded = (version?: number): boolean => {
    return wasLoaded && (!version || version <= itemStorage.version);
};

/**
 * Load item data from API.
 * @param newVersion If set and larger than 0 will only load data if local version is older.
 * @returns true if data was loaded successfully, false otherwise.
 */
export const loadItemData = async (): Promise<boolean> => {
    if (isLoadingPromise) return await isLoadingPromise;

    let resolver: (value: boolean) => void;
    isLoadingPromise = new Promise((res) => {
        resolver = res;
    });

    const itemData = await apiGet<ApiItemListRes>("/api/items/all");
    if (itemData.error) {
        alert("Failed to load item data: " + itemData.error);
        resolver!(false);
        return false;
    }

    for (const item of itemData.list) {
        itemStorage.items[item.itemId] = item;
    }
    itemStorage.version = itemData.version;

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
export const getItemData = (itemId: number): ApiItemEntry | undefined => {
    return itemStorage.items[itemId];
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
    // TODO: Fix this in DB?
    iconName = iconName.toLowerCase();
    return `https://wow.zamimg.com/images/wow/icons/small/${iconName}.jpg`;
};
