/**
 * Global Setup for Playwright Tests
 * 
 * This file can be used as a global setup hook in playwright.config.js
 * However, since we need to handle dangerous warnings after each page.goto(),
 * it's better to use the handleDangerousWarning utility in beforeEach hooks.
 */

module.exports = async () => {
  // Global setup code can go here if needed
  // For dangerous warning handling, use handleDangerousWarning in beforeEach hooks
}

