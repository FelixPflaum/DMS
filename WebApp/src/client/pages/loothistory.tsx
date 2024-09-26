import { useEffect, useRef, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { apiGet } from "../serverApi";
import type { ApiLootHistoryEntry, ApiLootHistoryPageRes } from "@/shared/types";
import LootResponse from "../components/LootResponse";
import { isItemDataLoaded, loadItemData } from "../data/itemStorage";
import ItemIconLink from "../components/item/ItemIconLink";

const LootHistoryPage = (): JSX.Element => {
    const [historyData, setHistoryData] = useState<{
        lastPageOffset: number;
        data: ApiLootHistoryEntry[];
        haveMore: boolean;
    }>({
        lastPageOffset: 0,
        data: [],
        haveMore: true,
    });
    const loadctx = useLoadOverlayCtx();
    const loadBtnRef = useRef<HTMLButtonElement>(null);

    const loadPage = async (page: number): Promise<void> => {
        loadctx.setLoading("fetchLootHistory", "Loading history...");
        apiGet<ApiLootHistoryPageRes>("/api/loothistory/page/" + page).then((pageRes) => {
            loadctx.removeLoading("fetchLootHistory");
            if (pageRes.error) return alert("Failed to get loot history page: " + pageRes.error);
            setHistoryData({
                lastPageOffset: pageRes.pageOffset,
                data: pageRes.entries.concat(historyData.data),
                haveMore: pageRes.haveMore,
            });
        });
    };

    useEffect(() => {
        if (!isItemDataLoaded()) {
            loadctx.setLoading("loadItemData", "Loading item data...");
            loadItemData().then(() => {
                loadctx.removeLoading("loadItemData");
                loadPage(0);
            });
        } else {
            loadPage(0);
        }
    }, []);

    const loadMore = () => {
        const nextPage = historyData.lastPageOffset + 1;
        if (!loadBtnRef.current) return;
        loadBtnRef.current.disabled = true;
        loadPage(nextPage).then(() => {
            if (loadBtnRef.current) loadBtnRef.current.disabled = false;
        });
    };

    const columDefs: ColumnDef<ApiLootHistoryEntry>[] = [
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
        //{ name: "GUID", dataKey: "guid" },
        {
            name: "Player",
            dataKey: "playerName",
            canSort: true,
            defaultSort: "asc",
        },
        {
            name: "Item",
            dataKey: "itemId",
            render: (rd) => <ItemIconLink itemId={rd.itemId}></ItemIconLink>,
        },
        { name: "Response", dataKey: "response", render: (rd) => <LootResponse dataText={rd.response}></LootResponse> },
    ];

    return (
        <>
            <h1 className="pageHeading">Loot History</h1>
            <Tablel columnDefs={columDefs} data={historyData.data} sortCol="timestamp" sortDir="desc"></Tablel>
            {historyData.haveMore ? (
                <button className="button" onClick={loadMore} ref={loadBtnRef}>
                    Load more
                </button>
            ) : null}
        </>
    );
};

export default LootHistoryPage;
