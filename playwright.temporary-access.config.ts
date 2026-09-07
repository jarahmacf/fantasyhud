import { defineConfig, devices } from "@playwright/test"

export default defineConfig({
  testDir: "./e2e/temporary-access",
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: 0,
  workers: 1,
  reporter: "list",
  use: {
    baseURL: "http://127.0.0.1:3102",
    ...devices["Desktop Chrome"],
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  webServer: {
    command:
      "npm run build && npm run start -- --hostname 127.0.0.1 --port 3102",
    url: "http://127.0.0.1:3102",
    timeout: 120_000,
    reuseExistingServer: false,
  },
})
