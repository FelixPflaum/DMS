import type { FormEventHandler } from "react";
import { useRef } from "react";
import NumberInput from "./form/NumberInput";
import TextInput from "./form/TextInput";
import { apiPost } from "../serverApi";
import type { ApiPointChangeRequest, ApiPointChangeResult } from "@/shared/types";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { useToaster } from "./toaster/Toaster";

const PointChangeForm = ({
    playerName,
    onChange,
}: {
    playerName: string | undefined;
    onChange: (change: number, newPoints: number) => void;
}): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const toaster = useToaster();
    const changeValueInputRef = useRef<HTMLInputElement>(null);
    const reasonInputRef = useRef<HTMLInputElement>(null);
    const submitBtnRef = useRef<HTMLButtonElement>(null);

    const onSubmit: FormEventHandler<HTMLFormElement> = (event) => {
        event.preventDefault();
        if (!playerName) return;

        const changeValue = parseInt(changeValueInputRef.current?.value ?? "x");
        const reasonValue = reasonInputRef.current?.value;
        if (typeof changeValue !== "number" || !reasonValue) return;

        if (!submitBtnRef.current) return;
        submitBtnRef.current.disabled = true;

        const body: ApiPointChangeRequest = {
            playerName: playerName,
            change: changeValue,
            reason: reasonValue,
        };

        loadctx.setLoading("addpointschange", "Adding point change");
        apiPost<ApiPointChangeResult>("/api/players/pointchange/", body).then((res) => {
            loadctx.removeLoading("addpointschange");
            if (submitBtnRef.current) submitBtnRef.current.disabled = false;
            if (res.error) {
                return toaster.addToast("Adding Entry Failed", res.error, "error");
            }
            toaster.addToast("Change Added", `Added ${body.change} sanity to ${body.playerName}.`, "success");
            if (changeValueInputRef.current) changeValueInputRef.current.value = "";
            if (reasonInputRef.current) reasonInputRef.current.value = "";
            onChange(res.change, res.newPoints);
        });
        return false;
    };

    return (
        <form onSubmit={onSubmit}>
            <NumberInput label="Change Value" inputRef={changeValueInputRef}></NumberInput>
            <TextInput label="Reason" inputRef={reasonInputRef}></TextInput>
            <div>
                <button className="button" ref={submitBtnRef}>
                    Add to History
                </button>
            </div>
        </form>
    );
};

export default PointChangeForm;
