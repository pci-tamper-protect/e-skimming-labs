// @ts-check
import { defineConfig, devices } from '@playwright/test'
import { currentEnv, TEST_ENV } from './config/test-env.js'

console.log(`🧪 E2E Test Environment: ${TEST_ENV}`)
console.log(`🔗 Base URL: ${currentEnv.homeIndex}`)

/**
 * @see https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
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
    baseURL: currentEnv.homeIndex,

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',

    /* Screenshot on failure */
    screenshot: 'only-on-failure',

    /* Video recording */
    video: 'retain-on-failure',

    /* Set timeout - longer for production due to network latency */
    actionTimeout: TEST_ENV === 'prd' ? 30000 : 30000,
    navigationTimeout: TEST_ENV === 'prd' ? 30000 : 30000,

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

  /* Run your local dev server before starting the tests (local only) */
  webServer: TEST_ENV === 'local'
    ? {
        command: 'cd .. && ./docker-labs.sh start home-index',
        url: currentEnv.homeIndex,
        reuseExistingServer: !process.env.CI,
        timeout: 120 * 1000
      }
    : undefined
})
