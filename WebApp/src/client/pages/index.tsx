import { useEffect } from "react";
import { apiGet } from "../serverApi";
import type { ApiSelfPlayerRes } from "@/shared/types";
import { useNavigate } from "react-router";

const HomePage = (): JSX.Element => {
    const navigate = useNavigate();
    useEffect(() => {
        apiGet<ApiSelfPlayerRes>("/api/players/self").then((playersRes) => {
            if (playersRes.error) return;
            if (playersRes.myChars.length > 0) {
                navigate("/profile?name=" + playersRes.myChars[0].playerName);
            }
        });
    }, []);
    return <></>;
};

export default HomePage;
