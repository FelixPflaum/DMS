import styles from "./form.module.css";

const NumberInput = ({
    label,
    inputRef,
    required,
}: {
    label: string;
    inputRef: React.RefObject<HTMLInputElement>;
    required?: boolean;
}): JSX.Element => {
    const onChange: React.ChangeEventHandler<HTMLInputElement> = (event) => {
        event.target.value = event.target.value.replace(/^[^-0-9]|(?!^)\D/g, "");
    };

    return (
        <div className={styles.inputWrap}>
            <label className={styles.inputLabel} htmlFor={label}>
                {label}
            </label>
            <input className={styles.input} id={label} ref={inputRef} onChange={onChange} required={required}></input>
        </div>
    );
};

export default NumberInput;
