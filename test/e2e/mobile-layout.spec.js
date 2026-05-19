// @ts-check
const { test, expect } = require('@playwright/test')
const { currentEnv, TEST_ENV } = require('../config/test-env')
const { handleDangerousWarning } = require('../utils/handle-dangerous-warning')
const { skipIfAuthRedirect } = require('../utils/skip-if-auth-redirect')
const { setMobileViewport } = require('../utils/nav')

const mobileLayoutTests =
  TEST_ENV === 'stg' && process.env.USE_PROXY !== 'true' ? test.describe.skip : test.describe

async function gotoOrSkip(page, url, label) {
  let response
  try {
    response = await page.goto(url, { timeout: 8000 })
  } catch (error) {
    test.skip(true, `${label} unavailable (${error.message})`)
    return
  }

  if (!response || response.status() >= 400) {
    test.skip(true, `${label} unavailable (HTTP ${response?.status() ?? 'error'})`)
  }

  await handleDangerousWarning(page)
  await skipIfAuthRedirect(page, label)
}

mobileLayoutTests('Mobile layout (forms, tabs, tables)', () => {
  test.beforeEach(async ({ page }) => {
    await setMobileViewport(page)
  })

  test('Lab 2 banking tabs scroll on narrow viewport', async ({ page }) => {
    await gotoOrSkip(page, `${currentEnv.lab2.vulnerable}/banking.html`, 'Lab 2 banking')

    const tabList = page.locator('.lab-tabs ul')
    await expect(tabList).toBeVisible()
    await expect(tabList).toHaveCSS('overflow-x', /auto|scroll/)
    await expect(tabList.locator('.tab-link').first()).toBeVisible()
  })

  test('Lab 1 checkout stacks card fields on mobile', async ({ page }) => {
    await gotoOrSkip(page, `${currentEnv.lab1.vulnerable}/checkout_single.html`, 'Lab 1 checkout')

    const cardRow = page.locator('.card-row')
    await expect(cardRow).toBeVisible()

    const tops = await cardRow.locator('.form-group').evaluateAll((els) =>
      els.map((el) => el.getBoundingClientRect().top)
    )
    expect(tops.length).toBeGreaterThan(1)
    expect(tops[1]).toBeGreaterThan(tops[0])
  })

  test('Lab 3 checkout form rows are single column', async ({ page }) => {
    await gotoOrSkip(page, `${currentEnv.lab3.vulnerable}/`, 'Lab 3 checkout')

    const formRow = page.locator('.form-row').first()
    await expect(formRow).toBeVisible()
    const columnCount = await formRow.evaluate((el) => {
      const columns = getComputedStyle(el).gridTemplateColumns.trim()
      return columns ? columns.split(/\s+/).length : 0
    })
    expect(columnCount).toBe(1)
  })

  test('Lab 2 C2 dashboard keeps captured data readable on mobile', async ({ page }) => {
    await gotoOrSkip(page, `${currentEnv.lab2.c2}/`, 'Lab 2 C2')

    await expect(page.locator('.data-section').first()).toBeVisible()
  })

  test('Lab 1 C2 dashboard pre blocks scroll horizontally', async ({ page }) => {
    await gotoOrSkip(page, `${currentEnv.lab1.c2}/`, 'Lab 1 C2')

    const pre = page.locator('.stolen-record pre').first()
    if ((await pre.count()) === 0) {
      await expect(page.locator('.data-section, .container').first()).toBeVisible()
      return
    }
    const preStyle = await pre.evaluate((el) => getComputedStyle(el).overflowX)
    expect(['auto', 'scroll']).toContain(preStyle)
  })
})
