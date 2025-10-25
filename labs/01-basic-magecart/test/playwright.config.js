// @ts-check
const { defineConfig, devices } = require('@playwright/test')

// Get the variant from environment variable (defaults to 'base')
const SKIMMER_VARIANT = process.env.SKIMMER_VARIANT || 'base'

// Map variants to their test files
const variantTestMap = {
  base: ['checkout.spec.js'],
  'obfuscated-base64': ['obfuscated-base64.spec.js'],
  'event-listener-variant': ['event-listener-variant.spec.js'],
  'websocket-exfil': ['websocket-exfil.spec.js']
}

// Get test pattern for current variant
const testMatch = variantTestMap[SKIMMER_VARIANT] || ['checkout.spec.js']

console.log(`🧪 Running tests for variant: ${SKIMMER_VARIANT}`)
console.log(`📋 Test files: ${testMatch.join(', ')}`)

/**
 * @see https://playwright.dev/docs/test-configuration
 */
module.exports = defineConfig({
  testDir: './tests',
  testMatch: testMatch,
  /* Run tests in files in parallel */
  fullyParallel: true,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,
  /* Opt out of parallel tests on CI. */
  workers: process.env.CI ? 1 : undefined,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: 'html',
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: 'http://localhost:9001',

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',

    /* Screenshot on failure */
    screenshot: 'only-on-failure',

    /* Video recording */
    video: 'retain-on-failure',

    /* Set timeout to 8 seconds for local pages */
    actionTimeout: 8000,
    navigationTimeout: 8000
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    }
  ],

  /* Run your local dev server before starting the tests */
  webServer: {
    command: 'cd ../../.. && docker-compose up lab1-vulnerable-site lab1-c2-server',
    url: 'http://localhost:9001',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000
  }
})
