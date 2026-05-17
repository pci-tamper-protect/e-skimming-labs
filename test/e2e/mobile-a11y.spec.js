// @ts-check
const { test, expect } = require('@playwright/test')
const AxeBuilder = require('@axe-core/playwright').default
const { currentEnv, TEST_ENV } = require('../config/test-env')
const { handleDangerousWarning } = require('../utils/handle-dangerous-warning')
const { openHomeNavMenu } = require('../utils/nav')

/** @param {import('axe-core').Result[]} violations */
function formatViolations(violations) {
  return violations
    .map((v) => `${v.id}: ${v.help} (${v.nodes.length} element(s))`)
    .join('\n')
}

const mobileA11yTests =
  TEST_ENV === 'stg' && process.env.USE_PROXY !== 'true' ? test.describe.skip : test.describe

mobileA11yTests('Mobile accessibility (axe)', () => {
  test.beforeEach(async ({ page }) => {
    const response = await page.goto(currentEnv.homeIndex)
    if (response && response.status() >= 400) {
      throw new Error(
        `HTTP ${response.status()} when accessing ${currentEnv.homeIndex}`
      )
    }
    await handleDangerousWarning(page)
    await page.waitForLoadState('networkidle')
    await openHomeNavMenu(page)
  })

  test('home page passes WCAG-focused axe scan', async ({ page }) => {
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'best-practice'])
      .analyze()

    expect(results.violations, formatViolations(results.violations)).toEqual([])
  })

  test('interactive controls meet tap target size (target-size)', async ({ page }) => {
    const results = await new AxeBuilder({ page })
      .withRules(['target-size'])
      .analyze()

    expect(results.violations, formatViolations(results.violations)).toEqual([])
  })
})
