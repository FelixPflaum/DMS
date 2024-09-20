import styles from "./form.module.css";

const TextInput = ({
    label,
    inputRef,
    required,
    minLen,
}: {
    label: string;
    inputRef: React.RefObject<HTMLInputElement>;
    required?: boolean;
    minLen?: number;
}): JSX.Element => {
    return (
        <div className={styles.inputWrap}>
            <label className={styles.inputLabel} htmlFor={label}>
                {label}
            </label>
            <input className={styles.input} id={label} ref={inputRef} required={required} minLength={minLen}></input>
        </div>
    );
};

export default TextInput;
