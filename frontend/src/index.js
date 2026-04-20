import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";
import { GoogleOAuthProvider } from "@react-oauth/google";
import { AuthProvider } from "./context/AuthContext";

const root = ReactDOM.createRoot(document.getElementById("root"));

// Fallback to a dummy string to prevent the app from crashing if the env var is missing,
// though Google login will fail until a valid ID is provided in .env
const clientId = process.env.REACT_APP_GOOGLE_CLIENT_ID || "dummy_client_id.apps.googleusercontent.com";

root.render(
  <GoogleOAuthProvider clientId={clientId}>
    <AuthProvider>
      <App />
    </AuthProvider>
  </GoogleOAuthProvider>
);