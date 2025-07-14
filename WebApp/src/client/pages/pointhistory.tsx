import { useEffect, useRef, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { apiGet } from "../serverApi";
import type { ApiPointHistoryEntry, ApiPointHistoryPageRes } from "@/shared/types";
import { useToaster } from "../components/toaster/Toaster";
import styles from "../styles/pagePointHist.module.css";
import type { LootHistoryRow } from "@/server/database/types";
import { getLootHistoryEntry } from "../data/lootHistory";
import ItemIconLink from "../components/item/ItemIconLink";
import { isGuid } from "@/shared/guid";

const PointHistoryPage = (): JSX.Element => {
    const toaster = useToaster();
    const [historyData, setHistoryData] = useState<{
        lastPageOffset: number;
        data: ApiPointHistoryEntry[];
        haveMore: boolean;
    }>({
        lastPageOffset: -1,
        data: [],
        haveMore: true,
    });
    const [lootData, setLootData] = useState<Record<string, LootHistoryRow | false>>({});
    const loadctx = useLoadOverlayCtx();
    const loadBtnRef = useRef<HTMLButtonElement>(null);

    const loadMore = () => {
        const nextPage = historyData.lastPageOffset + 1;
        if (!loadBtnRef.current) return;
        loadBtnRef.current.disabled = true;
        loadctx.setLoading("fetchPointHistory", "Loading history...");
        apiGet<ApiPointHistoryPageRes>("/api/pointhistory/page/" + nextPage).then((pageRes) => {
            if (loadBtnRef.current) loadBtnRef.current.disabled = false;
            loadctx.removeLoading("fetchPointHistory");
            if (pageRes.error) return toaster.addToast("Failed Loading More", pageRes.error, "error");
            setHistoryData({
                lastPageOffset: pageRes.pageOffset,
                data: pageRes.entries.concat(historyData.data),
                haveMore: pageRes.haveMore,
            });
        });
    };

    useEffect(() => {
        loadMore();
    }, []);

    const columDefs: ColumnDef<ApiPointHistoryEntry>[] = [
        {
            name: "Time",
            dataKey: "timestamp",
            defaultSort: "desc",
            canSort: true,
            render: (rd) => {
                const dt = new Date(rd.timestamp);
                return dt.toLocaleString();
            },
        },
        {
            name: "Player",
            dataKey: "playerName",
            canSort: true,
            defaultSort: "asc",
        },
        {
            name: "Change",
            dataKey: "pointChange",
            render: (rd) => (
                <span className={rd.pointChange > 0 ? styles.changePositive : styles.changeNegative}>
                    {rd.pointChange > 0 ? "+" + rd.pointChange : rd.pointChange}
                </span>
            ),
        },
        { name: "New Sanity", dataKey: "newPoints" },
        { name: "Change Type", dataKey: "changeType" },
        {
            name: "Reason",
            dataKey: "reason",
            render: (rd) => {
                if (!rd.reason) return "";
                if (rd.changeType != "ITEM_AWARD" && rd.changeType != "ITEM_AWARD_REVERTED") return rd.reason;
                if (!isGuid(rd.reason)) return rd.reason;

                const guid = rd.reason;
                const ld = lootData[guid];
                if (typeof ld !== "undefined") {
                    if (!ld) return rd.reason + " (Unknown Loot!)";
                    return <ItemIconLink itemId={ld.itemId}></ItemIconLink>;
                }

                getLootHistoryEntry(guid)
                    .then((data) => {
                        const newData = { ...lootData };
                        newData[guid] = data ?? false;
                        setLootData(newData);
                    })
                    .catch((err) => {
                        const msg = err instanceof Error ? err.message : String(err);
                        toaster.addToast(
                            "Missing loot data!",
                            `Could not get loot data for ${rd.reason}!\nError: ${msg}`,
                            "error"
                        );
                    });

                return rd.reason + " (...)";
            },
        },
    ];

    return (
        <>
            <h1 className="pageHeading">Sanity History</h1>
            <Tablel columnDefs={columDefs} data={historyData.data} sortCol="timestamp" sortDir="desc"></Tablel>
            {historyData.haveMore ? (
                <button className="button" onClick={loadMore} ref={loadBtnRef}>
                    Load more
                </button>
            ) : null}
        </>
    );
};

export default PointHistoryPage;
