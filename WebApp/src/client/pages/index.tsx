import { useEffect } from "react";
import { apiGet } from "../serverApi";
import type { PlayerEntry } from "@/shared/types";
import { useNavigate } from "react-router";

const HomePage = (): JSX.Element => {
    const navigate = useNavigate();
    useEffect(() => {
        apiGet<PlayerEntry[]>("/api/players/self", "get own player list").then((playersRes) => {
            if (playersRes && playersRes.length > 0) {
                navigate("/profile?name=" + playersRes[0].playerName);
            }
        });
    }, []);
    return <></>;
};

export default HomePage;
