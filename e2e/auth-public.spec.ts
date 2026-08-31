import { expect, test, type Page } from "@playwright/test"

test.describe.configure({ mode: "serial" })

let page: Page

test.beforeAll(async ({ browser }) => {
  page = await browser.newPage()
})

test.afterAll(async () => {
  await page.close()
})

async function prepareVisualPage(page: Page, path: string) {
  await page.goto(path)
  await page.evaluate(async () => {
    document.documentElement.classList.add("dark")
    await document.fonts.ready
  })
  await page.addStyleTag({
    content:
      "*, *::before, *::after { animation-duration: 0s !important; animation-delay: 0s !important; transition-duration: 0s !important; caret-color: transparent !important; }",
  })
}

test("sign-in desktop visual", async () => {
  await page.setViewportSize({ width: 1536, height: 1024 })
  await prepareVisualPage(page, "/auth/sign-in")
  await expect(page).toHaveScreenshot("sign-in-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
})

test("sign-up desktop visual", async () => {
  await page.setViewportSize({ width: 1536, height: 1024 })
  await prepareVisualPage(page, "/auth/sign-up")
  await expect(page).toHaveScreenshot("sign-up-desktop.png", {
    animations: "disabled",
    fullPage: true,
  })
})

test("sign-in mobile visual", async () => {
  await page.setViewportSize({ width: 390, height: 844 })
  await prepareVisualPage(page, "/auth/sign-in")
  await expect(page).toHaveScreenshot("sign-in-mobile.png", {
    animations: "disabled",
    fullPage: true,
  })
})
