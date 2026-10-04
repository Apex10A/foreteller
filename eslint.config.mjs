import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";
import prettier from "eslint-config-prettier/flat";
import tseslint from "typescript-eslint";

const supabaseClientOnlyInRepositories = {
  group: ["@supabase/*", "@supabase/*/**"],
  message: "Only files in src/server/repositories may import a Supabase client.",
};

const eslintConfig = defineConfig([
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    // Added for this project:
    "coverage/**",
  ]),

  ...nextVitals,
  ...nextTs,

  {
    files: ["**/*.ts", "**/*.tsx", "**/*.mts"],
    extends: [tseslint.configs.recommendedTypeChecked],
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-non-null-assertion": "error",
      "@typescript-eslint/ban-ts-comment": [
        "error",
        {
          "ts-ignore": true,
          "ts-nocheck": true,
          "ts-expect-error": "allow-with-description",
        },
      ],
      "@typescript-eslint/consistent-type-imports": [
        "error",
        { prefer: "type-imports", fixStyle: "inline-type-imports" },
      ],
      "no-console": "error",
    },
  },

  // Env vars are read in exactly one place so they can be Zod-validated.
  {
    files: ["src/**/*.ts", "src/**/*.tsx"],
    ignores: ["src/lib/env.ts"],
    rules: {
      "no-restricted-properties": [
        "error",
        {
          object: "process",
          property: "env",
          message: "Read environment variables through src/lib/env.ts.",
        },
      ],
    },
  },

  // Flow is route -> service -> repository / prediction engine.
  {
    files: ["src/app/**/*.ts", "src/app/**/*.tsx"],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              group: ["@/server/repositories/*", "@/server/providers/*", "@/server/prediction/*"],
              message: "app/ must call a service in @/server/services, never skip layers.",
            },
            supabaseClientOnlyInRepositories,
          ],
        },
      ],
    },
  },

  // Prediction logic stays pure: no I/O, no framework, no data access.
  {
    files: ["src/server/prediction/**/*.ts"],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              group: [
                "@/server/repositories/*",
                "@/server/providers/*",
                "@/server/services/*",
                "@/lib/env",
                "@supabase/*",
                "next",
                "next/*",
              ],
              message: "Prediction functions must be pure with no I/O.",
            },
          ],
        },
      ],
    },
  },

  {
    files: [
      "src/server/services/**/*.ts",
      "src/server/providers/**/*.ts",
      "src/features/**/*.ts",
      "src/features/**/*.tsx",
      "src/lib/**/*.ts",
    ],
    rules: {
      "no-restricted-imports": ["error", { patterns: [supabaseClientOnlyInRepositories] }],
    },
  },

  {
    files: ["**/*.test.ts", "**/*.test.tsx", "vitest.setup.ts"],
    rules: {
      "no-restricted-imports": "off",
      "no-restricted-properties": "off",
    },
  },

  prettier,
]);

export default eslintConfig;
