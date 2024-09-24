import React from "react";
import ReactDOM from "react-dom/client";
import "@/client/styles/global.css";
import "@/client/styles/wow.css";
import App from "@/client/App";
import { BrowserRouter } from "react-router-dom";

const container = document.getElementById("root");
const root = ReactDOM.createRoot(container!);
root.render(
    <React.StrictMode>
        <BrowserRouter>
            <App />
        </BrowserRouter>
    </React.StrictMode>
);
