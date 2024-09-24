import styles from "./form.module.css";

const StaticFormRow = ({ label, value }: { label: string; value: string }): JSX.Element => {
    return (
        <div className={styles.inputWrap}>
            <label className={styles.inputLabel}>{label}</label>
            <span>{value}</span>
        </div>
    );
};

export default StaticFormRow;
