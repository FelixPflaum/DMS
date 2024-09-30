import type { FormEventHandler } from "react";
import { useRef } from "react";
import NumberInput from "./form/NumberInput";
import TextInput from "./form/TextInput";
import { apiPost } from "../serverApi";
import type { ApiMultiPointChangeRequest, ApiMultiPointChangeResult } from "@/shared/types";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { useToaster } from "./toaster/Toaster";

const PointChangeFormMulti = ({
    onChange,
}: {
    onChange: (updates: { playerName: string; newPoints: number }[], change: number) => void;
}): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const toaster = useToaster();
    const namesInputRef = useRef<HTMLInputElement>(null);
    const changeValueInputRef = useRef<HTMLInputElement>(null);
    const reasonInputRef = useRef<HTMLInputElement>(null);
    const submitBtnRef = useRef<HTMLButtonElement>(null);

    const onSubmit: FormEventHandler<HTMLFormElement> = (event) => {
        event.preventDefault();

        const namesValue = namesInputRef.current?.value;
        const changeValue = parseInt(changeValueInputRef.current?.value ?? "x");
        const reasonValue = reasonInputRef.current?.value;
        if (typeof changeValue !== "number" || !reasonValue) return false;
        if (!namesValue) return false;

        if (!submitBtnRef.current) return;
        submitBtnRef.current.disabled = true;

        const body: ApiMultiPointChangeRequest = {
            playerNames: namesValue.split(",").map((v) => v.trim()),
            change: changeValue,
            reason: reasonValue,
        };

        loadctx.setLoading("addmultipointschange", "Adding sanity changes");
        apiPost<ApiMultiPointChangeResult>("/api/players/multipointchange", body).then((res) => {
            loadctx.removeLoading("addmultipointschange");
            if (submitBtnRef.current) submitBtnRef.current.disabled = false;
            if (res.error) {
                return toaster.addToast("Adding Entries Failed", res.error, "error");
            }
            toaster.addToast("Changes Added", `Added ${body.change} sanity to ${body.playerNames.join(", ")}.`, "success");
            if (changeValueInputRef.current) changeValueInputRef.current.value = "";
            if (reasonInputRef.current) reasonInputRef.current.value = "";
            if (namesInputRef.current) namesInputRef.current.value = "";
            onChange(res.updates, res.change);
        });
        return false;
    };

    return (
        <form onSubmit={onSubmit}>
            <TextInput label="Names" inputRef={namesInputRef} minLen={2} required={true}></TextInput>
            <NumberInput label="Change Value" inputRef={changeValueInputRef} required={true}></NumberInput>
            <TextInput label="Reason" inputRef={reasonInputRef} required={true}></TextInput>
            <div>
                <button className="button" ref={submitBtnRef}>
                    Add to History
                </button>
            </div>
        </form>
    );
};

export default PointChangeFormMulti;
