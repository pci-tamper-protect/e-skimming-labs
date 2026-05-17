/**
 * Shared navigation labels for lab pages and Playwright tests.
 *
 * - ariaLabel: stable accessible name (use in tests via getByRole)
 * - text: visible label (shorter for mobile layouts)
 * - icon: optional prefix shown in the link
 *
 * HTML nav links should use aria-label="{ariaLabel}" and visible text "{icon} {text}".
 */
const NAV_LABELS = {
  labsHome: {
    ariaLabel: 'Labs Home',
    text: 'Labs Home',
    icon: '←',
  },
  attackServer: {
    ariaLabel: 'Attack Server',
    text: 'Attack Server',
    icon: '🕵️',
  },
  backToLab: {
    ariaLabel: 'Back to Lab',
    text: 'Back to Lab',
    icon: '←',
  },
  writeup: {
    ariaLabel: 'Lab Writeup',
    text: 'Writeup',
    icon: '📖',
  },
  homeMenuOpen: {
    ariaLabel: 'Open navigation menu',
    text: 'Menu',
  },
  homeMenuClose: {
    ariaLabel: 'Close navigation menu',
    text: 'Menu',
  },
}

/** @param {keyof typeof NAV_LABELS} key */
function formatNavLink(key) {
  const item = NAV_LABELS[key]
  return item.icon ? `${item.icon} ${item.text}` : item.text
}

/**
 * Playwright locator for a nav link by config key (matches aria-label).
 * @param {import('@playwright/test').Page} page
 * @param {keyof typeof NAV_LABELS} key
 */
function navLink(page, key) {
  return page.getByRole('link', { name: NAV_LABELS[key].ariaLabel })
}

module.exports = {
  NAV_LABELS,
  formatNavLink,
  navLink,
}
