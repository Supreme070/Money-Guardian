import React from "react";
import ReactDOM from "react-dom/client";
import { ConfigProvider } from "antd";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { AdminAuthProvider } from "@/lib/adminAuth";
import App from "@/App";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
    },
  },
});

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ConfigProvider
      theme={{
        token: {
          colorPrimary: "#375EFD",
          borderRadius: 8,
          fontFamily: "Mulish, -apple-system, BlinkMacSystemFont, sans-serif",
        },
      }}
    >
      <QueryClientProvider client={queryClient}>
        <AdminAuthProvider>
          <App />
        </AdminAuthProvider>
      </QueryClientProvider>
    </ConfigProvider>
  </React.StrictMode>,
);
