import { useContext, createContext, useState } from "react";
import LoadOverlay from "./components/LoadOverlay";

type LoadOverlayContextType = {
    /**
     * Set loading state.
     * @param key Unique key. If not unique will be silently ignored.
     * @param test The overlay status text.
     */
    setLoading: (key: string, text: string) => void;
    /**
     * Remove loading overlay.
     * @param key The key used to add it.
     */
    removeLoading: (key: string) => void;
};

type OverlayData = {
    key: string;
    text: string;
};

const LoadOverlayContext = createContext<LoadOverlayContextType>({
    setLoading: () => {},
    removeLoading: () => {},
});

export const useLoadOverlayCtx = (): LoadOverlayContextType => useContext<LoadOverlayContextType>(LoadOverlayContext);

const overlayList: OverlayData[] = [];

const LoadOverlayProvider = ({ children }: { children: JSX.Element[] }): JSX.Element => {
    const [overLayText, setOverlayText] = useState<string | null>(null);

    const setLoading = (key: string, text: string): void => {
        if (!overlayList.find((el) => el.key == key)) {
            overlayList.push({ key, text });
            if (overlayList.length == 1) {
                setOverlayText(overlayList[0].text);
            }
        }
    };

    const removeLoading = (key: string): void => {
        const existingPos = overlayList.findIndex((el) => el.key == key);
        if (existingPos !== -1) {
            overlayList.splice(existingPos, 1);
            if (existingPos === 0) {
                setOverlayText(overlayList[0] ? overlayList[0].text : null);
            }
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
