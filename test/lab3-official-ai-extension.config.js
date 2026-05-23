// @ts-check
const { defineConfig, devices } = require('@playwright/test')

module.exports = defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI
    ? [
        ['html'],
        ['json', { outputFile: 'test-results/lab3-official-ai-extension-results.json' }],
        ['junit', { outputFile: 'test-results/lab3-official-ai-extension-junit.xml' }]
      ]
    : [['list'], ['html', { open: 'never' }]],
  use: {
    actionTimeout: 10000,
    navigationTimeout: 10000,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    video: 'retain-on-failure'
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        launchOptions: {
          headless: true,
          args: ['--no-sandbox', '--disable-dev-shm-usage']
        }
      }
    },
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        launchOptions: {
          headless: true
        }
      }
    },
    {
      name: 'webkit',
      use: {
        ...devices['Desktop Safari'],
        launchOptions: {
          headless: true
        }
      }
    }
  ]
})
