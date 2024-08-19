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

let lua = `--------------------------------------------------------------------
--- Generated file, do not edit.
--------------------------------------------------------------------

---@class AddonEnv
local Env = select(2, ...)

local L = Env:AddLocalization("enUS")
`;

for (const str in allStrings) {
    lua += `L["${str}"] = "${str}"\n`;
}

writeFileSync(ADDON_DIR + "/Locale/enUS.lua", lua);
console.log("Wrote enUS.lua.");
