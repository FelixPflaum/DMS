import { Suspense } from "react";
import { useRoutes } from "react-router-dom";
import routes from "~react-pages";
import Header from "./components/Header";
import LoadOverlayProvider from "./LoadOverlayProvider";
import LoadOverlay from "./components/LoadOverlay";
import AuthProvider from "./AuthProvider";

function App(): JSX.Element {
    return (
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
    );
}

export default App;
