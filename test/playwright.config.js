// @ts-check
const { defineConfig, devices } = require('@playwright/test')

/**
 * @see https://playwright.dev/docs/test-configuration
 */
module.exports = defineConfig({
  testDir: './e2e',
  /* Run tests in files in parallel */
  fullyParallel: true,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,
  /* Limit workers to prevent too many browser instances */
  workers: process.env.CI ? 1 : 2,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: 'html',
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: 'http://localhost:3000',

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',

    /* Screenshot on failure */
    screenshot: 'only-on-failure',

    /* Video recording */
    video: 'retain-on-failure',

    /* Set timeout to 30 seconds for local pages (increased for slower loading) */
    actionTimeout: 30000,
    navigationTimeout: 30000,

    /* Ensure proper browser cleanup */
    launchOptions: {
      headless: true,
      args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-web-security']
    }
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // Ensure proper cleanup
        launchOptions: {
          headless: true,
          args: ['--no-sandbox', '--disable-dev-shm-usage']
        }
      }
    },
    {
      name: 'chrome-mobile',
      use: {
        ...devices['Pixel 5'],
        launchOptions: {
          headless: true,
          args: ['--no-sandbox', '--disable-dev-shm-usage']
        }
      }
    },
    {
      name: 'chrome-tablet',
      use: {
        ...devices['iPad Pro'],
        launchOptions: {
          headless: true,
          args: ['--no-sandbox', '--disable-dev-shm-usage']
        }
      }
    }
  ],

  /* Run your local dev server before starting the tests */
  webServer: {
    command: 'cd .. && ./docker-labs.sh start home-index',
    url: 'http://localhost:3000', // Changed from 8080 to 3000
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000
  }
})
