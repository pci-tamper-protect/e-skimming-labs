const { test } = require('@playwright/test')

/**
 * Skip the current test if the page was redirected to the sign-in page.
 * Call after any navigation that could be auth-gated.
 */
async function skipIfAuthRedirect(page, labName) {
  const url = page.url()
  if (url.includes('/sign-in')) {
    console.log(`⏭️  ${labName} redirected to sign-in — skipping (set TEST_USER_EMAIL_* to run with auth)`)
    test.skip()
  }
}

module.exports = { skipIfAuthRedirect }
