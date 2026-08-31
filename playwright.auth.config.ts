import { defineConfig, devices } from "@playwright/test"

const baseURL = "http://127.0.0.1:3101"

export default defineConfig({
  testDir: "./e2e/auth",
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: 0,
  workers: 1,
  reporter: "html",
  expect: {
    toHaveScreenshot: {
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
      name: "auth-chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command:
      "npm run build && npm run start -- --hostname 127.0.0.1 --port 3101",
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
})
