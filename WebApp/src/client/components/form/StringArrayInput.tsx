import styles from "./form.module.css";

const StringArrayInput = ({
    label,
    value,
    onChange,
    onChangeKey,
    customInputClass,
}: {
    label: string;
    value: string[];
    onChange?: (key: string, val: string[]) => void;
    onChangeKey?: string;
    customInputClass?: string;
}): JSX.Element => {
    const classes = [styles.input];
    if (customInputClass) classes.push(customInputClass);

    const _onChange: React.ChangeEventHandler<HTMLInputElement> = (e) => {
        const val = e.target.value.trim();
        const strings = val ? e.target.value.split(",").map((v) => v.trim()) : [];
        if (onChange) onChange(onChangeKey ?? "", strings);
    };

    return (
        <div className={styles.inputWrap}>
            <label className={styles.inputLabel} htmlFor={label}>
                {label}
            </label>
            <input className={classes.join(" ")} id={label} value={value.join(",")} onChange={_onChange}></input>
        </div>
    );
};

export default StringArrayInput;
