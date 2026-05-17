const { NAV_LABELS, formatNavLink, navLink } = require('../../config/nav-labels.cjs')

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
  openHomeNavMenu,
}
