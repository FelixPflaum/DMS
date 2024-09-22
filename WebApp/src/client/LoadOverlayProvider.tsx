import { useContext, createContext, useState } from "react";
import LoadOverlay from "./components/LoadOverlay";

const DEFAULT_DELAY = 250;

type LoadOverlayContextType = {
    /**
     * Set loading state.
     * @param key Unique key. If same key is used will update display.
     * @param test The overlay status text.
     * @param showDelay Delay showing the overlay. Prevents short flashes on very quick loads. Default 250ms
     */
    setLoading: (key: string, text: string, showDelay?: number) => void;
    /**
     * Remove loading overlay.
     * @param key The key used to add it.
     */
    removeLoading: (key: string) => void;
};

type OverlayData = {
    key: string;
    text: string;
    showAt: number;
};

const LoadOverlayContext = createContext<LoadOverlayContextType>({
    setLoading: () => {},
    removeLoading: () => {},
});

export const useLoadOverlayCtx = (): LoadOverlayContextType => useContext<LoadOverlayContextType>(LoadOverlayContext);

// TODO: wth is the react solution to have that in a function component?
const overlayList: OverlayData[] = [];
let timer: number | undefined;

const LoadOverlayProvider = ({ children }: { children: JSX.Element[] | JSX.Element }): JSX.Element => {
    const [overLayText, setOverlayText] = useState<string | null>(null);

    const updateShown = () => {
        if (timer) clearTimeout(timer);
        if (!overlayList[0]) return setOverlayText("");
        const showIn = overlayList[0].showAt - Date.now();
        if (showIn <= 0) {
            console.log("Show now", overlayList[0].key);
            setOverlayText(overlayList[0].text);
        } else {
            console.log("Show in", showIn, overlayList[0].key);
            timer = setTimeout(updateShown, showIn + 1) as unknown as number; // This is browserland
        }
    };

    const setLoading = (key: string, text: string, showDelay = DEFAULT_DELAY): void => {
        console.log("setLoading", key, text);
        const existingPos = overlayList.findIndex((el) => el.key == key);
        if (existingPos === -1) {
            overlayList.push({ key, text, showAt: Date.now() + showDelay });
            if (overlayList.length == 1) updateShown();
        } else {
            overlayList[existingPos].text = text;
            if (existingPos == 0) updateShown();
        }
    };

    const removeLoading = (key: string): void => {
        console.log("removeLoading", key);
        const existingPos = overlayList.findIndex((el) => el.key == key);
        if (existingPos !== -1) {
            overlayList.splice(existingPos, 1);
            if (existingPos === 0) updateShown();
        }
    };

    return (
        <LoadOverlayContext.Provider value={{ setLoading, removeLoading }}>
            {children}
            {overLayText ? <LoadOverlay text={overLayText}></LoadOverlay> : null}
        </LoadOverlayContext.Provider>
    );
};

export default LoadOverlayProvider;
