import type { CSSProperties } from "react";

const LootResponse = ({ dataText }: { dataText: string }): JSX.Element => {
    let display = dataText;
    const style: CSSProperties = {};
    const match = display.match(/{(\d+),(\S+)}(.+)/);
    if (match) {
        display = match[3];
        style.color = `#${match[2]}`;
    }

    return <span style={style}>{display}</span>;
};

export default LootResponse;
