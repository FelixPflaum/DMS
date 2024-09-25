import styles from "./form.module.css";

const NumberInput = ({
    label,
    inputRef,
    value,
    onChange,
    onChangeKey,
    customInputClass,
    required,
}: {
    label: string;
    inputRef?: React.RefObject<HTMLInputElement>;
    value?: number;
    onChange?: (key: string, val: number) => void;
    onChangeKey?: string;
    customInputClass?: string;
    required?: boolean;
}): JSX.Element => {
    const classes = [styles.input];
    if (customInputClass) classes.push(customInputClass);

    const _onChange: React.ChangeEventHandler<HTMLInputElement> = (event) => {
        if (onChange) onChange(onChangeKey ?? "", parseFloat(event.target.value) || 0);
    };

    return (
        <div className={styles.inputWrap}>
            <label className={styles.inputLabel} htmlFor={label}>
                {label}
            </label>
            <input
                type="number"
                className={classes.join(" ")}
                id={label}
                ref={inputRef}
                value={value}
                onChange={_onChange}
                required={required}
            ></input>
        </div>
    );
};

export default NumberInput;
