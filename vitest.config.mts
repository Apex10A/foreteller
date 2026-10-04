import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    projects: [
      {
        resolve: { tsconfigPaths: true },
        test: {
          name: "server",
          environment: "node",
          include: ["src/{server,lib}/**/*.test.ts"],
        },
      },
      {
        resolve: { tsconfigPaths: true },
        plugins: [react()],
        test: {
          name: "ui",
          environment: "jsdom",
          setupFiles: ["./vitest.setup.ts"],
          include: ["src/{app,features}/**/*.test.{ts,tsx}"],
        },
      },
    ],
  },
});
