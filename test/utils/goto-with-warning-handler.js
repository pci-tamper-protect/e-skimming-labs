/**
 * Custom goto function that handles dangerous warnings
 * 
 * This function wraps page.goto() and automatically handles Chrome's dangerous
 * warning page if it appears. Use this instead of page.goto() in your tests.
 * 
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @param {string} url - URL to navigate to
 * @param {object} options - Options to pass to page.goto()
 * @returns {Promise<import('@playwright/test').Response>} - Response from page.goto()
 */
import { handleDangerousWarning } from './handle-dangerous-warning.js'

export async function gotoWithWarningHandler(page, url, options = {}) {
  // Navigate to the page
  const response = await page.goto(url, options)
  
  // Handle dangerous warning if present
  await handleDangerousWarning(page)
  
  return response
}

