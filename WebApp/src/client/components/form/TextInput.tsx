import styles from "./form.module.css";

const TextInput = ({
    label,
    inputRef,
    value,
    onChange,
    onChangeKey,
    customInputClass,
    required,
    minLen,
}: {
    label: string;
    inputRef?: React.RefObject<HTMLInputElement>;
    value?: string;
    onChange?: (key: string, val: string) => void;
    onChangeKey?: string;
    customInputClass?: string;
    required?: boolean;
    minLen?: number;
}): JSX.Element => {
    const classes = [styles.input];
    if (customInputClass) classes.push(customInputClass);

    const _onChange: React.ChangeEventHandler<HTMLInputElement> = (e) => {
        if (onChange) onChange(onChangeKey ?? "", e.target.value);
    };

    return (
        <div className={styles.inputWrap}>
            <label className={styles.inputLabel} htmlFor={label}>
                {label}
            </label>
            <input
                className={classes.join(" ")}
                id={label}
                ref={inputRef}
                required={required}
                minLength={minLen}
                value={value}
                onChange={_onChange}
            ></input>
        </div>
    );
};

export default TextInput;
