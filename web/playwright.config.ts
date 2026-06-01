import { defineConfig, devices } from "@playwright/test";

// Targets the dev server running on :3000 by default.
// Run a single browser context per test (we create per-user contexts inside
// the test for pair-flow scenarios). Headed mode toggled via PWDEBUG=1.

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false, // pair flow shares Supabase state — serialize for now
  forbidOnly: !!process.env.CI,
  // Realtime delivery over a shared Supabase project is occasionally flaky
  // under concurrent channels; one retry locally absorbs that without masking
  // real regressions (the app has its own resync safety net).
  retries: process.env.CI ? 2 : 1,
  workers: 1,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:3000",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: process.env.E2E_BASE_URL
    ? undefined
    : {
        command: "npm run dev",
        url: "http://localhost:3000",
        reuseExistingServer: true,
        timeout: 60_000,
        // Anon "試玩" sign-in is gated behind this flag in app code; the e2e
        // suite drives it, so enable it for the test dev server only. (Also
        // mirrored in .env.local so a reused dev server has it too.)
        env: { NEXT_PUBLIC_ENABLE_TEST_SIGNIN: "1" },
      },
});
