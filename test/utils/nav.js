const { NAV_LABELS, formatNavLink, navLink } = require('../../config/nav-labels.cjs')

/**
 * Narrow viewport used by mobile layout/CSS tests (matches @media max-width: 768px).
 * @param {import('@playwright/test').Page} page
 */
async function setMobileViewport(page) {
  await page.setViewportSize({ width: 375, height: 667 })
}

/**
 * Locator for the docs/lab "back to home" link (supports legacy and current labels).
 * @param {import('@playwright/test').Page} page
 */
function labsHomeLink(page) {
  return page.getByRole('link', { name: /Labs Home|Back to Labs/i })
}

/**
 * Opens the home page hamburger menu when the mobile toggle is visible.
 * @param {import('@playwright/test').Page} page
 */
async function openHomeNavMenu(page) {
  const menuButton = page.getByRole('button', { name: NAV_LABELS.homeMenuOpen.ariaLabel })
  if (!(await menuButton.isVisible())) {
    return
  }
  if ((await menuButton.getAttribute('aria-expanded')) !== 'true') {
    await menuButton.click()
  }
  await page.getByRole('navigation', { name: 'Site navigation' }).waitFor({ state: 'visible' })
}

module.exports = {
  NAV_LABELS,
  formatNavLink,
  navLink,
  labsHomeLink,
  setMobileViewport,
  openHomeNavMenu,
}
