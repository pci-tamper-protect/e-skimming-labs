import { defineConfig, devices } from '@playwright/test';
import path from 'path';

/**
 * Playwright configuration for AI Extension E-Skimming Lab
 *
 * Two test suites are defined:
 *
 * 1. "chromium" project  — ai-extension-skimming.spec.ts
 *    Uses the standard headless Playwright browser context.  These tests prove
 *    the DOM-level attack mechanics (textContent vs innerText, MutationObserver
 *    detection, etc.) without needing a real extension.
 *
 * 2. "extension" project — ai-extension-with-fixture.spec.ts
 *    Uses chromium.launchPersistentContext with --load-extension to load the
 *    fixture-extension/ stub extension into a real (headful) Chrome instance.
 *    This is the closest Playwright can get to testing actual AI assistant
 *    extension behaviour.  See ai-extension-with-fixture.spec.ts for details.
 *
 * Playwright docs on Chrome extension testing:
 *   https://playwright.dev/docs/chrome-extensions
 */
export default defineConfig({
  testDir: '.',
  testMatch: '**/*.spec.ts',
  
  /* Maximum time one test can run */
  timeout: 30_000,
  
  /* Fail the build on CI if you accidentally left test.only in the source code */
  forbidOnly: !!process.env.CI,
  
  /* Retry on CI only */
  retries: process.env.CI ? 1 : 0,
  
  /* Reporter configuration */
  reporter: [
    ['html', { outputFolder: 'evidence/report' }],
    ['list']
  ],
  
  /* Shared settings for all projects */
  use: {
    /* Base URL for local server */
    baseURL: 'http://localhost:3119',
    
    /* Capture screenshot on failure */
    screenshot: 'on',
    
    /* Record HAR per test worker to avoid file collisions during parallel runs.
     * Playwright creates one BrowserContext per test; the HAR is written when the
     * context closes. Using a unique path per worker prevents overwrites. */
    contextOptions: {
      recordHar: {
        path: path.join(__dirname, 'evidence', `network-trace-${process.pid}.har`),
        mode: 'full',
        content: 'embed'
      }
    },
    
    /* Collect trace on first retry */
    trace: 'on-first-retry',
    
    /* Video recording */
    video: 'on-first-retry',
  },

  /* Output directory for test artifacts (screenshots, videos, traces) */
  outputDir: 'evidence/artifacts',

  /* Configure projects for testing */
  projects: [
    {
      // Standard headless project — DOM-level simulation tests
      name: 'chromium',
      testMatch: '**/ai-extension-skimming.spec.ts',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      // Real-extension project — loads fixture-extension/ via --load-extension
      // These tests manage their own BrowserContext (launchPersistentContext)
      // so they don't inherit the global `use` browser options.
      name: 'extension',
      testMatch: '**/ai-extension-with-fixture.spec.ts',
      use: {
        // Headful is required for Playwright extension loading.
        // The extension tests call chromium.launchPersistentContext directly,
        // so these settings are informational only — the spec controls launch.
        headless: false,
        baseURL: 'http://localhost:3119',
      },
    },
  ],

  /* Run a local web server before starting the tests */
  webServer: {
    command: 'npx serve ../vulnerable-site -l 3119 --no-clipboard',
    port: 3119,
    timeout: 10_000,
    reuseExistingServer: !process.env.CI,
  },
});
