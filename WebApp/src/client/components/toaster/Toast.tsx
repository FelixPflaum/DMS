import { useEffect, useState, type CSSProperties } from "react";
import styles from "./toaster.module.css";

const Toast = ({ data, onExpire }: { data: ToastData; onExpire: (id: number) => void }): JSX.Element => {
    const classes = [styles.toasterToast];
    const [durationWidth, setDurationWidth] = useState<number>(100);
    const [mouseInside, setMouseInside] = useState<boolean>(false);

    switch (data.type) {
        case "info":
            classes.push(styles.toasterTypeInfo);
            break;
        case "success":
            classes.push(styles.toasterTypeSuccess);
            break;
        case "error":
            classes.push(styles.toasterTypeError);
            break;
    }

    useEffect(() => {
        requestAnimationFrame(() => {
            if (mouseInside) {
                setDurationWidth(0);
                return;
            }
            const pctDone = (Date.now() - data.creationTime) / data.duration;

            if (pctDone > 1) {
                onExpire(data.id);
                return;
            }
            setDurationWidth((1 - pctDone) * 100);
        });
    }, [durationWidth]);

    const durStyle: CSSProperties = { width: `${durationWidth}%` };
    return (
        <div className={classes.join(" ")} onMouseEnter={() => setMouseInside(true)}>
            <button className={styles.toasterClose} onClick={() => onExpire(data.id)}>
                x
            </button>
            <h4 className={styles.toasterHeading}>{data.title} </h4>
            <p className={styles.toasterText}>{data.text}</p>
            <div className={styles.toasterDuration} style={durStyle}></div>
        </div>
    );
};

export default Toast;
