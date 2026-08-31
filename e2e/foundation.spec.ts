import { expect, test, type Page } from "@playwright/test"

async function prepareVisualPage(page: Page) {
  await page.goto("/foundation")
  await page.evaluate(async () => {
    document.documentElement.classList.add("dark")
    await document.fonts.ready
  })
  await page.addStyleTag({
    content:
      "*, *::before, *::after { animation-duration: 0s !important; animation-delay: 0s !important; transition-duration: 0s !important; caret-color: transparent !important; }",
  })
  const clearSearch = page.getByRole("button", { name: "Clear search" })
  if (await clearSearch.isVisible()) {
    await clearSearch.click()
  }
}

test.describe.configure({ mode: "serial" })

let page: Page

test.beforeAll(async ({ browser }) => {
  page = await browser.newPage()
})

test.afterAll(async () => {
  await page.close()
})

test("loads the truthful repository foundation dashboard", async () => {
  await page.goto("/foundation")

  await expect(page.getByText("FANTASY HUD", { exact: true })).toBeVisible()
  await expect(
    page.getByRole("heading", { level: 1, name: "Repository foundation" })
  ).toBeVisible()

  const table = page.getByRole("table", { name: "Foundation status" })
  await expect(table).toBeVisible()
  await expect(
    table.getByRole("row", {
      name: /Hosted development Configured Supabase GitHub integration/i,
    })
  ).toBeVisible()
  await expect(
    table.getByRole("row", {
      name: /Account identity model Ready Shared provider identity/i,
    })
  ).toBeVisible()

  for (const excluded of [
    /theme customizer/i,
    /customize columns/i,
    /add section/i,
  ]) {
    await expect(page.getByRole("button", { name: excluded })).toHaveCount(0)
  }
})

test("search filters all table fields and clearing restores rows", async () => {
  await page.goto("/foundation")

  const search = page.getByRole("searchbox", {
    name: "Search foundation status",
  })
  const table = page.getByRole("table", { name: "Foundation status" })

  await search.fill("pgTAP")
  await expect(table.getByRole("row")).toHaveCount(2)
  await expect(
    table.getByRole("row", { name: /Database tests Ready pgTAP/i })
  ).toBeVisible()
  await expect(page.getByRole("status")).toContainText("1 of 13 systems")

  await page.getByRole("button", { name: "Clear search" }).click()
  await expect(search).toHaveValue("")
  await expect(table.getByRole("row")).toHaveCount(14)
})

test("keyboard shortcut focuses search and columns sort accessibly", async () => {
  await page.goto("/foundation")
  const search = page.getByRole("searchbox", {
    name: "Search foundation status",
  })

  await page.keyboard.press("Control+K")
  await expect(search).toBeFocused()

  const systemHeader = page.getByRole("columnheader", { name: /System/i })
  await systemHeader.getByRole("button").click()
  await expect(systemHeader).toHaveAttribute("aria-sort", "ascending")
})

test("desktop foundation visual", async () => {
  await page.setViewportSize({ width: 1536, height: 1024 })
  await prepareVisualPage(page)

  await expect(page).toHaveScreenshot("foundation-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
})

test("mobile foundation visual", async () => {
  await page.setViewportSize({ width: 390, height: 844 })
  await prepareVisualPage(page)

  await expect(page).toHaveScreenshot("foundation-mobile.png", {
    animations: "disabled",
    fullPage: true,
  })
})

test("mobile sidebar opens and matches its visual baseline", async () => {
  await page.setViewportSize({ width: 390, height: 844 })
  await prepareVisualPage(page)

  await page.getByRole("button", { name: "Toggle Sidebar" }).click()
  await expect(page.getByText("Portfolio Command Center")).toBeVisible()
  await expect(page).toHaveScreenshot("foundation-mobile-sidebar-open.png", {
    animations: "disabled",
  })
})
