// @ts-check
const { test, expect } = require('@playwright/test')
const { currentEnv, TEST_ENV } = require('../config/test-env')
const { handleDangerousWarning } = require('../utils/handle-dangerous-warning')
const { skipIfAuthRedirect } = require('../utils/skip-if-auth-redirect')
const { setMobileViewport } = require('../utils/nav')

const mobileLayoutTests =
  TEST_ENV === 'stg' && process.env.USE_PROXY !== 'true' ? test.describe.skip : test.describe

mobileLayoutTests('Mobile layout (forms, tabs, tables)', () => {
  test.beforeEach(async ({ page }) => {
    try {
      const response = await page.goto(currentEnv.homeIndex, { timeout: 8000 })
      if (!response || response.status() >= 400) {
        test.skip(true, `Lab stack unavailable (HTTP ${response?.status() ?? 'error'})`)
      }
    } catch {
      test.skip(true, 'Lab stack unavailable (is docker-compose running on :8080?)')
    }
    await handleDangerousWarning(page)
    await setMobileViewport(page)
  })

  test('Lab 2 banking tabs scroll on narrow viewport', async ({ page }) => {
    await page.goto(`${currentEnv.lab2.vulnerable}/banking.html`)
    await skipIfAuthRedirect(page, 'Lab 2 banking')

    const tabList = page.locator('.lab-tabs ul')
    await expect(tabList).toBeVisible()
    await expect(tabList).toHaveCSS('overflow-x', /auto|scroll/)
    await expect(tabList.locator('.tab-link').first()).toBeVisible()
  })

  test('Lab 1 checkout stacks card fields on mobile', async ({ page }) => {
    await page.goto(`${currentEnv.lab1.vulnerable}/checkout_single.html`)
    await skipIfAuthRedirect(page, 'Lab 1 checkout')

    const cardRow = page.locator('.card-row')
    await expect(cardRow).toBeVisible()

    const tops = await cardRow.locator('.form-group').evaluateAll((els) =>
      els.map((el) => el.getBoundingClientRect().top)
    )
    expect(tops.length).toBeGreaterThan(1)
    expect(tops[1]).toBeGreaterThan(tops[0])
  })

  test('Lab 3 checkout form rows are single column', async ({ page }) => {
    await page.goto(`${currentEnv.lab3.vulnerable}/`)
    await skipIfAuthRedirect(page, 'Lab 3 checkout')

    const formRow = page.locator('.form-row').first()
    await expect(formRow).toBeVisible()
    await expect(formRow).toHaveCSS('grid-template-columns', /^1fr/)
  })

  test('Lab 2 C2 dashboard exposes scrollable tab bar', async ({ page }) => {
    await page.goto(`${currentEnv.lab2.c2}/`)
    await skipIfAuthRedirect(page, 'Lab 2 C2')

    const tabs = page.locator('.tabs')
    await expect(tabs).toBeVisible()
    await expect(tabs).toHaveCSS('overflow-x', /auto|scroll/)
  })

  test('Lab 1 C2 dashboard pre blocks scroll horizontally', async ({ page }) => {
    await page.goto(`${currentEnv.lab1.c2}/`)
    await skipIfAuthRedirect(page, 'Lab 1 C2')

    const pre = page.locator('.stolen-record pre').first()
    if ((await pre.count()) === 0) {
      await expect(page.locator('.data-section, .container').first()).toBeVisible()
      return
    }
    const preStyle = await pre.evaluate((el) => getComputedStyle(el).overflowX)
    expect(['auto', 'scroll']).toContain(preStyle)
  })
})
