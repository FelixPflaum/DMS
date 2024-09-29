import { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { apiGet } from "../serverApi";
import type { ApiProfileResult, ApiLootHistoryEntry, ApiPointHistoryEntry } from "@/shared/types";
import styles from "../styles/pageProfile.module.css";
import stylesPh from "../styles/pagePointHist.module.css";
import type { ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import ItemIconLink from "../components/item/ItemIconLink";
import LootResponse from "../components/LootResponse";
import { isItemDataLoaded, loadItemData } from "../data/itemStorage";
import { useToaster } from "../components/toaster/Toaster";

const ProfilePage = (): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const toaster = useToaster();
    const [searchParams, _setSearchParams] = useSearchParams();
    const [profile, setProfile] = useState<ApiProfileResult | undefined>();
    const navigate = useNavigate();

    const nameParam = searchParams.get("name");

    const waitForItemData = async () => {
        if (!isItemDataLoaded()) {
            loadctx.setLoading("loadItemData", "Loading item data...");
            await loadItemData();
            loadctx.removeLoading("loadItemData");
        }
        return;
    };

    useEffect(() => {
        if (!nameParam) return;
        loadctx.setLoading("fetchplayerprofile", "Loading profile data...");
        apiGet<ApiProfileResult>("/api/players/profile/" + nameParam).then((res) => {
            loadctx.removeLoading("fetchplayerprofile");
            if (res.error) {
                toaster.addToast("Loading User Failed", res.error, "error");
                navigate("/players");
                return;
            }
            waitForItemData().then(() => setProfile(res));
        });
    }, [nameParam]);

    const columDefsPoints: ColumnDef<ApiPointHistoryEntry>[] = [
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
            name: "Change",
            dataKey: "pointChange",
            render: (rd) => (
                <span className={rd.pointChange > 0 ? stylesPh.changePositive : stylesPh.changeNegative}>
                    {rd.pointChange > 0 ? "+" + rd.pointChange : rd.pointChange}
                </span>
            ),
        },
        { name: "New Sanity", dataKey: "newPoints" },
        { name: "Change Type", dataKey: "changeType" },
        { name: "Reason", dataKey: "reason" },
    ];

    const columDefsLoot: ColumnDef<ApiLootHistoryEntry>[] = [
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
            name: "Item",
            dataKey: "itemId",
            render: (rd) => <ItemIconLink itemId={rd.itemId}></ItemIconLink>,
        },
        { name: "Response", dataKey: "response", render: (rd) => <LootResponse dataText={rd.response}></LootResponse> },
        { name: "GUID", dataKey: "guid" },
    ];

    return (
        <>
            <h1 className="pageHeading">
                Profile: <span className={profile ? `classId${profile.player.classId}` : ""}>{nameParam}</span>
            </h1>
            <div className={styles.profileStats}>
                <span className={styles.profileStatLabel}>Current Sanity:</span>
                <span className={styles.profileStatValue}>{profile?.player.points}</span>
            </div>
            <div className={styles.profileData}>
                <div className={styles.profilePointHistory}>
                    <h3 className={styles.profileh3}>Sanity History</h3>
                    <Tablel
                        columnDefs={columDefsPoints}
                        data={profile?.pointHistory ?? []}
                        sortCol="timestamp"
                        sortDir="desc"
                    ></Tablel>
                </div>
                <div className={styles.profileLootHistory}>
                    <h3 className={styles.profileh3}>Loot History</h3>
                    <Tablel
                        columnDefs={columDefsLoot}
                        data={profile?.lootHistory ?? []}
                        sortCol="timestamp"
                        sortDir="desc"
                    ></Tablel>
                </div>
            </div>
        </>
    );
};

export default ProfilePage;
