import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Pin the workspace root so lockfiles outside the repository cannot shift it.
  turbopack: { root: import.meta.dirname },
};

export default nextConfig;
