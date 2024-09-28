import { useContext, createContext, useState, useRef } from "react";
import styles from "./toaster.module.css";
import Toast from "./Toast";

const durations: Record<ToastType, number> = {
    info: 7000,
    success: 7000,
    error: 11111,
};

type ToasterContextType = {
    /**
     * Add a toast.
     * @param data
     * @returns
     */
    addToast: (title: string, text: string, type: ToastType) => void;
};

const ToasterContext = createContext<ToasterContextType>({
    addToast: () => {},
});

export const useToaster = (): ToasterContextType => useContext<ToasterContextType>(ToasterContext);

const Toaster = ({ children }: { children: JSX.Element[] | JSX.Element }): JSX.Element => {
    const [toasts, setToasts] = useState<ToastData[]>([]);
    const persistentData = useRef<{ lastId: number; toasts: ToastData[] }>({ lastId: 0, toasts: [] });

    const onToastExpire = (id: number) => {
        const idx = persistentData.current.toasts.findIndex((v) => v.id == id);
        if (idx !== -1) {
            persistentData.current.toasts.splice(idx, 1);
            setToasts([...persistentData.current.toasts]);
        }
    };

    const addToast = (title: string, text: string, type: ToastType): void => {
        persistentData.current.toasts.push({
            id: persistentData.current.lastId++,
            title,
            text,
            creationTime: Date.now(),
            duration: durations[type],
            type,
        });
        setToasts([...persistentData.current.toasts]);
    };

    const toastElems = toasts.map((v) => <Toast key={v.id} data={v} onExpire={onToastExpire}></Toast>);

    return (
        <ToasterContext.Provider value={{ addToast }}>
            {children}
            <div className={styles.toasterArea}>{toastElems}</div>
        </ToasterContext.Provider>
    );
};

export default Toaster;
