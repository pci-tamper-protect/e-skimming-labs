// @ts-check
const { defineConfig } = require('@playwright/test')

module.exports = defineConfig({
  testDir: './test',
  /* Maximum time one test can run for. */
  timeout: 30 * 1000,
  /* Run tests in files in parallel */
  fullyParallel: true,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: 'html',
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Maximum time each action such as `click()` can take. Defaults to 0 (no limit). */
    actionTimeout: 10000,
    navigationTimeout: 10000,
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: 'http://localhost:9005',
    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',
    /* Screenshot on failure */
    screenshot: 'only-on-failure',
    /* Video recording */
    video: 'retain-on-failure'
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: 'chromium',
      use: {
        browserName: 'chromium',
        headless: false,
        viewport: { width: 1280, height: 720 }
      }
    }
  ],

  /* Run your local dev server before starting the tests */
  webServer: {
    command: 'cd ../../.. && docker-compose up lab3-vulnerable-site lab3-test-server',
    url: 'http://localhost:9005',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000
  }
})


