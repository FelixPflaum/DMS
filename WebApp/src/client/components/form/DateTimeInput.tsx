import styles from "./form.module.css";

const DateTimeInput = ({
    label,
    timestamp,
    onChangeKey,
    onChange,
    customInputClass,
}: {
    label: string;
    timestamp: number;
    onChange: (key: string, timestamp: number) => void;
    onChangeKey: string;
    customInputClass?: string;
}): JSX.Element => {
    const classes = [styles.input];
    if (customInputClass) classes.push(customInputClass);

    // Get YYYY-MM-SSTHH:MM time string for datetime input.
    const d = new Date(timestamp);
    const value = `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, "0")}-${d.getDate().toString().padStart(2, "0")}T${d.getHours().toString().padStart(2, "0")}:${d.getMinutes().toString().padStart(2, "0")}`;
    const offsetMinutes = d.getTimezoneOffset();

    const _onChange: React.ChangeEventHandler<HTMLInputElement> = (e) => {
        // Append :SS.MSSZ so parsing works correctly. Timezone can simply be added to the ms timestamp.
        const d = new Date(e.target.value + ":00.000Z");
        const localeTimestamp = d.getTime();
        const utcTimestamp = localeTimestamp ? localeTimestamp + offsetMinutes * 60 * 1000 : 0;
        if (onChange) onChange(onChangeKey, utcTimestamp);
    };

    return (
        <div className={styles.inputWrap}>
            <label className={styles.inputLabel} htmlFor={label}>
                {label}
            </label>
            <input type="datetime-local" className={classes.join(" ")} id={label} value={value} onChange={_onChange}></input>
        </div>
    );
};

export default DateTimeInput;
