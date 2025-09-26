import { classData } from "@/shared/wow";
import { ClassId } from "@/shared/wow";

import styles from "./form.module.css";

const shownClasses: ClassId[] = [
    ClassId.WARRIOR,
    ClassId.ROGUE,
    ClassId.HUNTER,
    ClassId.WARLOCK,
    ClassId.MAGE,
    ClassId.DRUID,
    ClassId.PRIEST,
    ClassId.SHAMAN,
    ClassId.PALADIN,
];

const options: JSX.Element[] = [];
for (const classId of shownClasses) {
    options.push(
        <option key={classId} value={classId}>
            {classData[classId].name}
        </option>
    );
}

const CharClassSelect = ({
    label,
    inputRef,
    value,
    onChange,
    onChangeKey,
    customInputClass,
}: {
    label: string;
    inputRef?: React.RefObject<HTMLSelectElement>;
    value?: ClassId;
    onChange?: (key: string, val: ClassId) => void;
    onChangeKey?: string;
    customInputClass?: string;
}): JSX.Element => {
    const classes = [styles.input];
    if (customInputClass) classes.push(customInputClass);

    const _onChange: React.ChangeEventHandler<HTMLSelectElement> = (e) => {
        const valNum = parseInt(e.target.value);
        if (onChange) onChange(onChangeKey ?? "", valNum);
    };

    return (
        <div className={styles.inputWrap}>
            <label className={styles.inputLabel} htmlFor={label}>
                {label}
            </label>
            <select className={classes.join(" ")} id={label} ref={inputRef} value={value} onChange={_onChange}>
                {options}
            </select>
        </div>
    );
};

export default CharClassSelect;
