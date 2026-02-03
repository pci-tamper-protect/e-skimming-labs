// @ts-check
const { defineConfig, devices } = require('@playwright/test')
const path = require('path')

// Load environment configuration
const testEnvPath = path.resolve(__dirname, '../../../test/config/test-env.js')
const { currentEnv, TEST_ENV } = require(testEnvPath)

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
console.log(`🌍 Environment: ${TEST_ENV}`)
console.log(`🔗 Base URL: ${currentEnv.lab1.vulnerable}`)

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
  /* Use file-based reporters to avoid hanging on browser popups */
  reporter: process.env.CI
    ? [['html', { outputFolder: 'playwright-report' }], ['json', { outputFile: 'test-results.json' }], ['list']]
    : [['html', { outputFolder: 'playwright-report', open: 'never' }], ['json', { outputFile: 'test-results.json' }], ['list']],
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: currentEnv.lab1.vulnerable,

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',

    /* Screenshot on failure */
    screenshot: 'only-on-failure',

    /* Video recording */
    video: 'retain-on-failure',

    /* Set timeout - longer for production due to network latency */
    actionTimeout: TEST_ENV === 'prd' ? 30000 : 8000,
    navigationTimeout: TEST_ENV === 'prd' ? 30000 : 8000
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    }
  ],

  /* Run your local dev server before starting the tests (local only) */
  webServer: TEST_ENV === 'local'
    ? {
        command: 'cd ../../.. && docker-compose up lab1-vulnerable-site lab1-c2-server',
        url: currentEnv.lab1.vulnerable,
        reuseExistingServer: !process.env.CI,
        timeout: 120 * 1000
      }
    : undefined
})
