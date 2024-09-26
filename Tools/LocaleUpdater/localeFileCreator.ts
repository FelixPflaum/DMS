import { readdirSync, readFileSync, statSync, writeFileSync } from "fs";
import { join } from "path";

const ADDON_DIR = __dirname + "/../../Addon";

const ignoredDirs: { [dirName: string]: boolean } = {
    Libs: true,
    _dev: true,
    Locale: true,
}

function scanForLtags(filePath: string, list: { [str: string]: boolean }) {
    const content = readFileSync(filePath, "utf-8");
    const matches = content.match(/L\s*\[".*?"\]/g);
    if (matches) {
        for (const match of matches) {
            let str = match.replace(/^L\s*\["/, "");
            str = str.substring(0, str.length - 2);
            list[str] = true;
        }
    }
}

function getLuaFileList(dir: string, list?: string[]) {
    list = list ?? [];
    const fileList = readdirSync(dir);
    for (const file of fileList) {
        const pathToFile = join(dir, file);
        if (statSync(pathToFile).isDirectory()) {
            if (!ignoredDirs[file]) getLuaFileList(pathToFile, list);
        } else if (file.split(".").pop() == "lua") {
            list.push(pathToFile);
        }
    }
    return list;
}

const files = getLuaFileList(ADDON_DIR);

const allStrings: { [str: string]: boolean } = {};
for (const file of files) {
    scanForLtags(file, allStrings);
}

function getExistingStrings(str: string): Record<string, string> {
    const strings: Record<string, string> = {};
    const lines = str.split("\n");
    for (const line of lines) {
        const match = line.match(/L\["(.*)"\] = "(.*)"/);
        if (match) {
            strings[match[1]] = match[2];
        }
    }
    return strings;
}

const localeDir = ADDON_DIR + "/Locale";
const localeFiles = readdirSync(localeDir);
for (const file of localeFiles) {
    if (file.startsWith("Local")) continue;
    const content = readFileSync(join(localeDir, file), "utf-8");
    const existing = getExistingStrings(content);

    let lua = `---@class AddonEnv
local Env = select(2, ...)
    
local L = Env:AddLocalization("${file.substring(1, file.length - 4)}")\n\n`;
    
    let newCount = 0;

    for (const str in allStrings) {
        if (existing[str]) {
            lua += `L["${str}"] = "${existing[str]}"\n`;
            delete existing[str]
        } else {
            lua += `L["${str}"] = "${str}"\n`;
            newCount++;
        }
    }

    let removedCount = Object.keys(existing).length;
    
    writeFileSync(ADDON_DIR + `/Locale/${file}`, lua);

    console.log(`Wrote ${file}. ${newCount} new entries. ${removedCount} entries no longer exist.`);
}
