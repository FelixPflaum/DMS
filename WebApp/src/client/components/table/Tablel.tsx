import { useState } from "react";
import styles from "./tablel.module.css";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type DataType = Record<string, any>;
export type SortType = "asc" | "desc";
export type ColumnDef<T extends DataType> = {
    name: string;
    dataKey: keyof T;
    canSort?: boolean;
    defaultSort?: SortType;
    customSort?: (a: T, b: T) => number;
    render?: (rowData: T) => JSX.Element;
};
export type ActionButtonStyle = "default" | "red";
export type ActionDef<T> = {
    name: string;
    style?: ActionButtonStyle;
    onClick: (rowData: T) => void;
};

type TablelProps<T extends DataType> = {
    columnDefs: ColumnDef<T>[];
    data: T[];
    sortCol?: keyof T;
    sortDir?: SortType;
    actions?: ActionDef<T>[];
};

const actionBtnStyleClasses: Record<ActionButtonStyle, string> = {
    default: styles.actionButtonDefault,
    red: styles.actionButtonRed,
};

function defaultSortFunc(val1: string | number, val2: string | number, sort: SortType): number {
    if (typeof val1 === "string") val1 = val1.toLowerCase();
    if (typeof val2 === "string") val2 = val2.toLowerCase();
    if (val1 < val2) {
        if (sort == "asc") {
            return -1;
        } else {
            return 1;
        }
    } else if (val1 > val2) {
        if (sort == "asc") {
            return 1;
        } else {
            return -1;
        }
    } else {
        return 0;
    }
}

const Tablel = <T extends DataType>({ columnDefs, data, sortCol, sortDir, actions }: TablelProps<T>): JSX.Element => {
    const [sortData, setSortData] = useState<{ col: keyof T; dir: SortType }>({
        col: sortCol ?? columnDefs[0].dataKey,
        dir: sortDir ?? "asc",
    });
    const headers: JSX.Element[] = [];
    const rows: JSX.Element[] = [];

    const changeSort = (col: string) => {
        if (sortData.col == col) {
            setSortData({ col, dir: sortData.dir == "asc" ? "desc" : "asc" });
        } else {
            setSortData({ col, dir: "asc" });
        }
    };

    for (const columnData of columnDefs) {
        headers.push(
            <th
                key={columnData.dataKey as string}
                className={`${styles.tableTh}${columnData.canSort ? " " + styles.sortable : ""}`}
                onClick={columnData.canSort ? () => changeSort(columnData.dataKey as string) : undefined}
            >
                {columnData.name}
            </th>
        );
    }

    if (actions && actions.length > 0) {
        headers.push(
            <th key="actions" className={styles.tableTh}>
                Actions
            </th>
        );
    }

    data.sort((a, b) => defaultSortFunc(a[sortData.col], b[sortData.col], sortData.dir));

    let listKey = 1;
    for (const rowData of data) {
        const tds: JSX.Element[] = [];
        for (const columnData of columnDefs) {
            const data = rowData[columnData.dataKey];
            const content = columnData.render ? columnData.render(rowData) : data;
            tds.push(
                <td key={columnData.dataKey as string} className={styles.tableTd}>
                    {content}
                </td>
            );
        }

        if (actions && actions.length > 0) {
            const actionElems: JSX.Element[] = [];
            for (const ae of actions) {
                actionElems.push(
                    <button
                        key={ae.name}
                        className={`${styles.tableActionButton} ${actionBtnStyleClasses[ae.style ?? "default"]}`}
                        onClick={() => ae.onClick(rowData)}
                    >
                        {ae.name}
                    </button>
                );
            }
            tds.push(
                <td key="actions" className={`${styles.tableTd} ${styles.tableActions}`}>
                    {actionElems}
                </td>
            );
        }

        rows.push(
            <tr key={listKey++} className={styles.tableTr}>
                {tds}
            </tr>
        );
    }

    return (
        <table className="table">
            <thead>
                <tr>{headers}</tr>
            </thead>
            <tbody>{rows}</tbody>
        </table>
    );
};

export default Tablel;
