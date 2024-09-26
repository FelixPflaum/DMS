import type { FormEventHandler } from "react";
import { useEffect, useRef, useState } from "react";
import TextInput from "../components/form/TextInput";
import NumberInput from "../components/form/NumberInput";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { apiGet, apiPost } from "../serverApi";
import type { ApiBackupListRes, ApiDynSettings, ApiMakeBackupRes, ApiSetSettingReq, ApiSettingRes } from "@/shared/types";
import StaticFormRow from "../components/form/StaticFormRow";
import styles from "../styles/pageSettings.module.css";
import DateTimeInput from "../components/form/DateTimeInput";
import FileList from "../components/fileList/FileList";
import StringArrayInput from "../components/form/StringArrayInput";
import PermissionInput from "../components/form/PermissionInput";

const SettingsPage = (): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const [loadedSettings, setLoadedSettings] = useState<ApiDynSettings | undefined>();
    const [currentSettings, setCurrentSettings] = useState<ApiDynSettings | undefined>();
    const submitBtnRef = useRef<HTMLButtonElement>(null);
    const rows: JSX.Element[] = [];

    useEffect(() => {
        loadctx.setLoading("fetchsettings", "Loading settings...");
        apiGet<ApiSettingRes>("/api/settings/get").then((res) => {
            loadctx.removeLoading("fetchsettings");
            if (res.error) return alert("Could not load settings data: " + res.error);
            setLoadedSettings(res.settings);
            setCurrentSettings(res.settings);
        });
    }, []);

    const onInputChange = (key: string, val: string | number | string[]) => {
        if (!currentSettings) return;
        if (!(key in currentSettings)) return;
        const newSettings = { ...currentSettings };
        // @ts-ignore
        newSettings[key as keyof ApiDynSettings] = val;
        setCurrentSettings(newSettings);
    };

    if (currentSettings && loadedSettings) {
        let key: keyof ApiDynSettings;
        for (key in currentSettings) {
            const val = currentSettings[key];
            const isChanged = val != loadedSettings[key];
            const addedClass = isChanged ? styles.changedInput : "";
            if (Array.isArray(val)) {
                rows.push(
                    <StringArrayInput
                        customInputClass={addedClass}
                        key={key}
                        label={key}
                        onChangeKey={key}
                        value={val}
                        onChange={onInputChange}
                    ></StringArrayInput>
                );
            } else if (key == "nextAutoDecay") {
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
            } else if (key == "defaultPerms") {
                rows.push(
                    <PermissionInput
                        customInputClass={addedClass}
                        key={key}
                        label={key}
                        perms={val}
                        onChangeKey={key}
                        onChange={onInputChange}
                    ></PermissionInput>
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

        let settingKey: keyof ApiDynSettings;
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
        apiPost("/api/settings/set", setReq).then((res) => {
            loadctx.removeLoading("setsettings");
            if (res.error) {
                alert("Updating settings failed: " + res.error);
            } else {
                alert("Settings updated.");
                setLoadedSettings({ ...currentSettings });
            }
        });
    };

    const [backList, setBackupList] = useState<string[]>([]);
    const [backupPath, setBackupPath] = useState<string[]>([]);
    const [selectedBackup, setSelectedBackup] = useState<string[] | undefined>();

    const onFileSelect = (file: string) => {
        if (backupPath.length < 2) {
            setBackupPath([...backupPath, file]);
        } else {
            console.log(file);
            setSelectedBackup([...backupPath, file]);
        }
    };

    const onBack = () => {
        if (backupPath.length > 0) {
            setBackupPath(backupPath.slice(0, -1));
            setSelectedBackup(undefined);
        }
    };

    const makeBackup = () => {
        loadctx.setLoading("makemackup", "Creating backup...");
        apiPost<ApiMakeBackupRes>("/api/backup/make", {}).then((res) => {
            loadctx.removeLoading("makemackup");
            if (res.error) {
                alert("Could not create backup: " + res.error);
                return;
            }
            alert("Backup created: " + res.file);
        });
    };

    const applyBackup = () => {
        if (!selectedBackup) return;
        const confirmWord = "YES";
        const promptRes = prompt(
            `Really apply backup?\nBackup file: ${selectedBackup[selectedBackup.length - 1]}\n\nThis will remove any changes made since that backup!\n\nEnter ${confirmWord} to confirm.`
        );
        if (promptRes && promptRes == confirmWord) {
            loadctx.setLoading("applybackup", "Applying backup...");
            apiPost("/api/backup/apply", { path: selectedBackup }).then((res) => {
                loadctx.removeLoading("applybackup");
                if (res.error) {
                    alert("Backup import failed: " + res.error);
                    return;
                }
                alert("Backup applied!");
                setSelectedBackup(undefined);
            });
        }
    };

    useEffect(() => {
        loadctx.setLoading("fetchbackuplist", "Loading backup list...");
        apiGet<ApiBackupListRes>("/api/backup/list/" + backupPath.join("/")).then((res) => {
            loadctx.removeLoading("fetchbackuplist");
            if (res.error) return alert("Failed to get backup list: " + res.error);
            setBackupList(res.list);
        });
    }, [backupPath]);

    const backupSelection = selectedBackup ? (
        <div className={styles.selectedBackupWrap}>
            <span className={styles.selectedBackupLabel}>Selected Backup</span>
            <span className={styles.selectedBackupName}>{selectedBackup.join("/")}</span>
            <button className="button" onClick={applyBackup}>
                Apply Backup
            </button>
        </div>
    ) : (
        <></>
    );

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
            <div>
                <h2 className="pageheading2">Backups</h2>
                <button className="button" onClick={makeBackup}>
                    Create New Backup
                </button>
                <h3 className="pageheading3">Backup List</h3>
                <div className={styles.fileListWrap}>
                    <FileList path={backupPath} files={backList} onBack={onBack} onSelect={onFileSelect}></FileList>
                </div>
                {backupSelection}
            </div>
        </>
    );
};

export default SettingsPage;
