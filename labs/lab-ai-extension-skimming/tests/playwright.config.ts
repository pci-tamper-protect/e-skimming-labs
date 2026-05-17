import { defineConfig, devices } from '@playwright/test';
import path from 'path';

/**
 * Playwright configuration for AI Extension E-Skimming Lab
 * 
 * Configures:
 * - Screenshot capture on test failure
 * - HAR recording for network analysis
 * - Evidence output directory
 * - Local web server for serving the vulnerable checkout page
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
    
    /* Record HAR for every test */
    contextOptions: {
      recordHar: {
        path: path.join(__dirname, 'evidence', 'network-trace.har'),
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
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
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
