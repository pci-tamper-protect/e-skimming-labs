// @ts-check
const { defineConfig, devices } = require('@playwright/test')
const { currentEnv, TEST_ENV } = require('./config/test-env')

console.log(`🧪 E2E Test Environment: ${TEST_ENV}`)
console.log(`🔗 Base URL: ${currentEnv.homeIndex}`)

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
  /* Maximize parallelization: use more workers for faster test execution
   * CI: Use 4 workers (GitHub Actions typically has 2-4 cores)
   * Local: Use 50% of CPU cores (default) or set via PLAYWRIGHT_WORKERS env var
   */
  workers: (() => {
    if (process.env.PLAYWRIGHT_WORKERS) {
      const workers = parseInt(process.env.PLAYWRIGHT_WORKERS, 10)
      return !Number.isNaN(workers) ? workers : (process.env.CI ? 4 : undefined)
    }
    return process.env.CI ? 4 : undefined // undefined = 50% of CPU cores (Playwright default)
  })(),
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  /* Use multiple reporters in CI for better sharding support */
  reporter: process.env.CI
    ? [
        ['html'],
        ['json', { outputFile: 'test-results/results.json' }],
        ['junit', { outputFile: 'test-results/junit.xml' }]
      ]
    : 'html',
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
  /* Note: If containers are already running, reuseExistingServer will skip starting them */
  webServer: TEST_ENV === 'local'
    ? {
        command: 'cd .. && docker-compose -f docker-compose.traefik.yml up -d traefik home-index',
        url: currentEnv.homeIndex,
        reuseExistingServer: true, // Always reuse if server is already running
        timeout: 120 * 1000
      }
    : undefined
})
