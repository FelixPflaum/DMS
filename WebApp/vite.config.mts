import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import eslint from "vite-plugin-eslint";
import Pages from "vite-plugin-pages";
import path from "path";
import { existsSync, readFileSync } from "fs";

export default defineConfig({
    root: "./src/client",
    envDir: "../",
    plugins: [
        react(),
        eslint(),
        Pages({
            pagesDir: [{ dir: "pages", baseRoute: "" }],
            extensions: ["tsx"],
        }),
        {
            name: "configcheck",
            async buildStart(_options) {
                if (!existsSync("config_client.json")) {
                    throw new Error("config_client.json is missing!");
                }
                const example = JSON.parse(readFileSync("config_client.json.example", "utf-8"));
                const cfg = JSON.parse(readFileSync("config_client.json", "utf-8"));
                let errCount = 0;
                for (const key in example) {
                    if (typeof cfg[key] === "undefined") {
                        console.error("Missing key in config_client.json: " + key);
                        errCount++;
                    } else if (typeof cfg[key] != typeof example[key]) {
                        console.error(`Value for key ${key} in config_client.json has the wrong type!`);
                        errCount++;
                    }
                }
                if (errCount) {
                    throw new Error("One or more settings in config_client.json are missing or wrong.");
                }
            },
        },
    ],
    resolve: {
        alias: {
            "@": path.resolve(__dirname, "src"),
        },
    },
    server: {
        proxy: {
            "/api": {
                target: "http://localhost:9001/",
                changeOrigin: true,
                // rewrite: (path) => path.replace(/^\/api\/v1/, ""),
            },
        },
        port: 9000,
    },
    build: {
        outDir: "../../build/client",
        assetsDir: "assets",
        sourcemap: true,
        manifest: true,
        rollupOptions: {
            output: {
                manualChunks: {
                    react: ["react", "react-dom"],
                },
            },
        },
    },
});
