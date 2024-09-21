import type { AccPermissions } from "@/shared/permissions";
import { permissionData } from "@/shared/permissions";
import styles from "./form.module.css";

const PermissionInput = ({
    label,
    perms,
    onChange,
}: {
    label: string;
    perms: AccPermissions;
    onChange: (perms: AccPermissions) => void;
}): JSX.Element => {
    const inputs: JSX.Element[] = [];

    for (const pd of Object.values(permissionData)) {
        if (pd.noUi) continue;
        const id = label + pd.name;
        inputs.push(
            <div key={id} className={styles.permInputRow}>
                <input
                    id={id}
                    type="checkbox"
                    checked={(perms & pd.value) !== 0}
                    onChange={() => onChange(perms ^ pd.value)}
                ></input>
                <label className={styles.permInputLabel} htmlFor={id}>
                    {pd.name}
                </label>
            </div>
        );
    }

    return (
        <div className={styles.inputWrap}>
            <label className={styles.inputLabel} htmlFor={label}>
                {label}
            </label>
            <div className={styles.permInputInputs}>{inputs}</div>
        </div>
    );
};

export default PermissionInput;
