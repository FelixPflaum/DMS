import * as fs from "fs";
import _7z from "7zip-min";
import { join } from "path";

const addonFolderName = "DamagedMindsSanity";
const base = join(__dirname, "../../Addon");
const version = fs.readFileSync(join(base, "/DamagedMindsSanity_Vanilla.toc"), "utf8").match(/## Version: (.*)/)![1];
const build = parseInt(fs.readFileSync(join(__dirname, "build.build"), "utf8"));

function shouldIgnore(file: string, isDir: boolean) {
    if (isDir) {
        if (file == "_dev") return true;
    } else {
        if (file.endsWith(".psd")) return true;
    }
}

interface FileList {
    [index: string]: FileList | string
}

function bpad(b: number) {
    let bs = b.toString();
    const pl = 4 - bs.length;
    for (let i = 0; i < pl; i++) bs = "0" + bs;
    return bs;
}

function getFileList(dir: string) {
    const list: FileList = {};
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const curPath = join(dir, file);
        if (fs.statSync(curPath).isDirectory()) {
            if (shouldIgnore(file, true)) continue;
            list[file] = getFileList(curPath);
        } else {
            if (shouldIgnore(file, false)) continue;
            list[file] = curPath;
        }
    }
    return list;
}

function rmFolder(path: string) {
    if (fs.existsSync(path)) {
        fs.readdirSync(path).forEach((file, index) => {
            const curPath = join(path, file);
            if (fs.lstatSync(curPath).isDirectory()) {
                rmFolder(curPath);
            } else {
                fs.unlinkSync(curPath);
            }
        });
        fs.rmdirSync(path);
    }
};

function copyToFolder(path: string, list: FileList) {
    for (let k in list) {
        const fod = list[k];
        const destPath = path + "/" + k;
        if (typeof fod === "string") {
            console.log("Copy " + fod);
            fs.copyFileSync(fod, destPath);
        } else {
            fs.mkdirSync(destPath);
            copyToFolder(destPath, fod);
        }
    }
}

const releaseDir = join(__dirname, "releases");
const tempDir = join(__dirname, addonFolderName);
const zipFileName = addonFolderName + "-" + version + "-" + build.toString().padStart(4, "0") + "-sod.zip";

console.log("Creating temp folder...");
fs.mkdirSync(tempDir);
copyToFolder(tempDir, getFileList(base));
console.log("Zipping...");
if (!fs.existsSync(releaseDir)) fs.mkdirSync(releaseDir);
_7z.pack(tempDir, join(releaseDir, zipFileName), err => {
    console.log("File written!");
    fs.writeFileSync(join(__dirname, "build.build"), (build + 1).toString());
    console.log("Remove temp folder...");
    rmFolder(tempDir);
    console.log("Done!");
});
