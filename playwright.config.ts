import { defineConfig, devices } from "@playwright/test"

const baseURL = "http://127.0.0.1:3100"

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI || process.platform === "darwin" ? 1 : undefined,
  reporter: "html",
  expect: {
    toHaveScreenshot: {
      // Allows only small cross-host antialiasing differences; layout drift still fails.
      maxDiffPixelRatio: 0.005,
      threshold: 0.2,
    },
  },
  use: {
    baseURL,
    launchOptions:
      process.platform === "darwin"
        ? { args: ["--single-process"] }
        : undefined,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command:
      "npm run build && npm run start -- --hostname 127.0.0.1 --port 3100",
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
})
