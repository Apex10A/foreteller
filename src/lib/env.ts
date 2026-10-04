import { z } from "zod";

/** Rejects placeholder secrets that are too short to be a real cron token. */
const MIN_CRON_SECRET_LENGTH = 16;

const serverEnvSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  FOOTBALL_API_KEY: z.string().min(1),
  CRON_SECRET: z.string().min(MIN_CRON_SECRET_LENGTH),
});

const clientEnvSchema = serverEnvSchema.pick({
  NEXT_PUBLIC_SUPABASE_URL: true,
  NEXT_PUBLIC_SUPABASE_ANON_KEY: true,
});

export type ServerEnv = z.infer<typeof serverEnvSchema>;
export type ClientEnv = z.infer<typeof clientEnvSchema>;

type EnvScope = "server" | "client";

export class EnvValidationError extends Error {
  constructor(scope: EnvScope, issues: string) {
    super(`Invalid ${scope} environment variables:\n${issues}`);
    this.name = "EnvValidationError";
  }
}

export class ServerEnvOnClientError extends Error {
  constructor() {
    super("Server environment variables are not available in the browser. Use getClientEnv().");
    this.name = "ServerEnvOnClientError";
  }
}

// Each NEXT_PUBLIC_* var is read as a static member expression so Next.js can
// inline its value into the client bundle at build time.
const clientRuntimeEnv = {
  NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
};

function parseEnv<Schema extends z.ZodType>(
  schema: Schema,
  source: unknown,
  scope: EnvScope,
): z.infer<Schema> {
  const result = schema.safeParse(source);
  if (!result.success) {
    throw new EnvValidationError(scope, z.prettifyError(result.error));
  }
  return result.data;
}

let cachedServerEnv: ServerEnv | undefined;
let cachedClientEnv: ClientEnv | undefined;

/**
 * Server-only environment variables, including secrets.
 * Throws rather than returning partial config so misconfiguration fails fast.
 */
export function getServerEnv(): ServerEnv {
  if (typeof window !== "undefined") {
    throw new ServerEnvOnClientError();
  }
  cachedServerEnv ??= parseEnv(serverEnvSchema, process.env, "server");
  return cachedServerEnv;
}

/** Environment variables that are safe to read from client components. */
export function getClientEnv(): ClientEnv {
  cachedClientEnv ??= parseEnv(clientEnvSchema, clientRuntimeEnv, "client");
  return cachedClientEnv;
}
