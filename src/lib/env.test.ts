import { afterEach, describe, expect, it, vi } from "vitest";

const VALID_ENV: Record<string, string> = {
  NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
  NEXT_PUBLIC_SUPABASE_ANON_KEY: "anon-key",
  SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
  FOOTBALL_API_KEY: "football-api-key",
  CRON_SECRET: "cron-secret-long-enough",
};

async function importEnv(overrides: Record<string, string | undefined> = {}) {
  vi.resetModules();
  for (const [key, value] of Object.entries({ ...VALID_ENV, ...overrides })) {
    vi.stubEnv(key, value);
  }
  return import("./env");
}

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe("getServerEnv", () => {
  it("returns every server variable when the environment is complete", async () => {
    const { getServerEnv } = await importEnv();

    expect(getServerEnv()).toEqual(VALID_ENV);
  });

  const invalidCases = [
    { name: "a missing service role key", overrides: { SUPABASE_SERVICE_ROLE_KEY: undefined } },
    { name: "a missing football API key", overrides: { FOOTBALL_API_KEY: undefined } },
    { name: "a blank anon key", overrides: { NEXT_PUBLIC_SUPABASE_ANON_KEY: "" } },
    { name: "a non-URL Supabase URL", overrides: { NEXT_PUBLIC_SUPABASE_URL: "not-a-url" } },
    { name: "a cron secret below the minimum length", overrides: { CRON_SECRET: "too-short" } },
  ];

  it.each(invalidCases)("throws EnvValidationError for $name", async ({ overrides }) => {
    const { getServerEnv, EnvValidationError } = await importEnv(overrides);

    expect(() => getServerEnv()).toThrow(EnvValidationError);
  });

  it("names the offending variable in the error message", async () => {
    const { getServerEnv } = await importEnv({ CRON_SECRET: undefined });

    expect(() => getServerEnv()).toThrow(/CRON_SECRET/);
  });

  it("refuses to read server secrets in the browser", async () => {
    const { getServerEnv, ServerEnvOnClientError } = await importEnv();
    vi.stubGlobal("window", {});

    expect(() => getServerEnv()).toThrow(ServerEnvOnClientError);
  });
});

describe("getClientEnv", () => {
  it("exposes only the public variables", async () => {
    const { getClientEnv } = await importEnv();

    expect(getClientEnv()).toEqual({
      NEXT_PUBLIC_SUPABASE_URL: VALID_ENV.NEXT_PUBLIC_SUPABASE_URL,
      NEXT_PUBLIC_SUPABASE_ANON_KEY: VALID_ENV.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    });
  });

  it("throws EnvValidationError when a public variable is missing", async () => {
    const { getClientEnv, EnvValidationError } = await importEnv({
      NEXT_PUBLIC_SUPABASE_ANON_KEY: undefined,
    });

    expect(() => getClientEnv()).toThrow(EnvValidationError);
  });
});
