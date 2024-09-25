import type { FormEventHandler } from "react";
import { useEffect, useRef, useState } from "react";
import TextInput from "../components/form/TextInput";
import NumberInput from "../components/form/NumberInput";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { apiGet, apiPost } from "../serverApi";
import type { ApiSetSettingReq, ApiSettingRes, UpdateRes } from "@/shared/types";
import StaticFormRow from "../components/form/StaticFormRow";
import styles from "../styles/pageSettings.module.css";
import DateTimeInput from "../components/form/DateTimeInput";

const SettingsPage = (): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const [loadedSettings, setLoadedSettings] = useState<ApiSettingRes | undefined>();
    const [currentSettings, setCurrentSettings] = useState<ApiSettingRes | undefined>();
    const submitBtnRef = useRef<HTMLButtonElement>(null);
    const rows: JSX.Element[] = [];

    useEffect(() => {
        loadctx.setLoading("fetchsettings", "Loading settings...");
        apiGet<ApiSettingRes>("/api/settings/get", "get settings data").then((res) => {
            loadctx.removeLoading("fetchsettings");
            if (!res) return;
            setLoadedSettings(res);
            setCurrentSettings(res);
        });
    }, []);

    const onInputChange = (key: string, val: string | number) => {
        if (!currentSettings) return;
        if (!(key in currentSettings)) return;
        const newSettings = { ...currentSettings };
        // @ts-ignore
        newSettings[key as keyof ApiSettingRes] = val;
        setCurrentSettings(newSettings);
    };

    if (currentSettings && loadedSettings) {
        let key: keyof ApiSettingRes;
        for (key in currentSettings) {
            const val = currentSettings[key];
            const isChanged = val != loadedSettings[key];
            const addedClass = isChanged ? styles.changedInput : "";
            if (key == "nextAutoDecay") {
                rows.push(
                    <DateTimeInput
                        customInputClass={addedClass}
                        key={key}
                        label={key}
                        timestamp={val}
                        onChangeKey={key}
                        onChange={onInputChange}
                    ></DateTimeInput>
                );
            } else if (typeof val === "string") {
                rows.push(
                    <TextInput
                        customInputClass={addedClass}
                        key={key}
                        label={key}
                        value={val}
                        onChangeKey={key}
                        onChange={onInputChange}
                    ></TextInput>
                );
            } else if (typeof val === "number") {
                rows.push(
                    <NumberInput
                        customInputClass={addedClass}
                        key={key}
                        label={key}
                        value={val}
                        onChangeKey={key}
                        onChange={onInputChange}
                    ></NumberInput>
                );
            } else {
                rows.push(<StaticFormRow key={key} label={key} value={val}></StaticFormRow>);
            }
        }
    }

    const onSubmit: FormEventHandler<HTMLFormElement> = (event) => {
        event.preventDefault();
        if (!loadedSettings || !currentSettings) return;

        const setReq: ApiSetSettingReq = { changes: [] };

        let settingKey: keyof ApiSettingRes;
        for (settingKey in currentSettings) {
            const valCurrent = currentSettings[settingKey];
            if (valCurrent != loadedSettings[settingKey]) {
                setReq.changes.push({
                    key: settingKey,
                    value: valCurrent,
                });
            }
        }

        if (setReq.changes.length == 0) return;

        loadctx.setLoading("setsettings", "Updating settings...");
        apiPost<UpdateRes>("/api/settings/set", "set settings", setReq).then((res) => {
            loadctx.removeLoading("setsettings");
            if (!res) return;
            if (!res.success) {
                let msg = "Updating settings failed: ";
                if (res.error) msg += res.error;
                alert(msg);
            } else {
                alert("Settings updated.");
                setLoadedSettings({ ...currentSettings });
            }
        });
    };

    return (
        <>
            <h1 className="pageHeading">Settings</h1>
            <form onSubmit={onSubmit}>
                {rows}
                <div>
                    <button className="button" ref={submitBtnRef}>
                        Save
                    </button>
                </div>
            </form>
        </>
    );
};

export default SettingsPage;
