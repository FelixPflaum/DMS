import { Suspense } from "react";
import { useRoutes } from "react-router-dom";
import routes from "~react-pages";
import Header from "./components/Header";
import LoadOverlayProvider from "./LoadOverlayProvider";
import LoadOverlay from "./components/LoadOverlay";
import AuthProvider from "./AuthProvider";
import Toaster from "./components/toaster/Toaster";

function App(): JSX.Element {
    return (
        <Toaster>
            <AuthProvider>
                <LoadOverlayProvider>
                    <Header></Header>
                    <main>
                        <Suspense fallback={<LoadOverlay text="Loading..." isTransparent={true}></LoadOverlay>}>
                            {useRoutes(routes)}
                        </Suspense>
                    </main>
                </LoadOverlayProvider>
            </AuthProvider>
        </Toaster>
    );
}

export default App;
