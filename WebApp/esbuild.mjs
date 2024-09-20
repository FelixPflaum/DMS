import { build, context } from "esbuild";
import { rmSync } from "fs";

rmSync("./build/server", { recursive: true, force: true });

const esbuildOptions = {
    entryPoints: ["src/server/server.ts"],
    bundle: true,
    sourcemap: true,
    format: "cjs",
    platform: "node",
    target: "node20",
    external: [],
    outfile: "./build/server/api.js",
    tsconfig: "./tsconfig.json",
};

function doWatch() {
    for (const arg of process.argv) {
        if (arg.indexOf("watch") !== -1) return true;
    }
    return false;
}

if (doWatch()) {
    console.log("Starting server build in watch mode...");
    if (!esbuildOptions.plugins) esbuildOptions.plugins = [];
    esbuildOptions.plugins.push({
        name: "rebuild-notify",
        setup(build) {
            build.onEnd((result) => {
                console.log(`Server rebuild ended with ${result.errors.length} errors.`);
            });
        },
    });
    const run = async () => {
        const esbctx = await context(esbuildOptions);
        esbctx.watch();
    };
    run();
} else {
    console.log("Building server...");
    const run = async () => {
        try {
            await build(esbuildOptions);
        } catch (error) {
            console.error(error);
            process.exit(1);
        }
    };
    run();
}
