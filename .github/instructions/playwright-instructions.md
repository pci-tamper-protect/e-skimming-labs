# Playwright Testing Guidelines

This document contains best practices and guidelines for writing reliable, maintainable Playwright tests for the E-Skimming Labs project.

## Table of Contents

- [General Principles](#general-principles)
- [Selector Best Practices](#selector-best-practices)
- [Text Matching](#text-matching)
- [Assertions](#assertions)
- [Table and Grid Testing](#table-and-grid-testing)
- [Common Pitfalls](#common-pitfalls)

---

## General Principles

### 1. Write Explicit, Not Clever Tests

**Bad:**
```javascript
await expect(page.getByText('4 techniques').first()).toBeVisible()
```

**Good:**
```javascript
await expect(countCells.nth(0)).toHaveText('4 techniques')  // Initial Access
```

**Why:** Explicit tests are easier to understand, debug, and maintain. Future developers should immediately know what's being tested.

### 2. Avoid Over-Fitting to Exact Counts

**Bad:**
```javascript
await expect(items).toHaveCount(42)  // Brittle - breaks when count changes
```

**Good:**
```javascript
await expect(items.count()).toBeGreaterThanOrEqual(40)  // Flexible
```

**Why:** Content grows over time. Unless the exact count is critical to functionality, use range checks (`>=`, `>`, `<=`, `<`) instead of exact equality.

### 3. Test Behavior, Not Implementation

Focus on what users see and do, not internal implementation details.

### 4. Use Proper Wait Strategies

**Bad:**
```javascript
await page.waitForTimeout(500)  // Hard-coded wait - brittle and slow
```

**Good:**
```javascript
// Wait for specific condition
await page.waitForSelector('.element', { state: 'visible' })
await expect(element).toBeVisible({ timeout: 10000 })

// Or use a helper function for complex waits
await waitForScrollComplete(page)
```

**Why:** Hard-coded timeouts are unreliable and slow down tests. Wait for specific conditions instead.

### 5. Add Timeout Options for Flaky Elements

**Bad:**
```javascript
await expect(element).toBeVisible()  // Uses default 5s timeout
```

**Good:**
```javascript
await expect(element).toBeVisible({ timeout: 10000 })  // Explicit timeout for slow-loading elements
```

**Why:** Some elements (like those loaded via network requests) may need more time. Explicit timeouts make tests more reliable.

---

## Selector Best Practices

### 1. Prefer Index-Based Selectors for Tables

**Bad:**
```javascript
const cell = page.locator('tbody tr td').first()
const anotherCell = page.locator('tbody tr td').nth(1)
```

**Good:**
```javascript
const initialAccessCell = matrixTable.locator('tbody tr td').nth(0)  // Column 0
const executionCell = matrixTable.locator('tbody tr td').nth(1)      // Column 1
const persistenceCell = matrixTable.locator('tbody tr td').nth(2)    // Column 2
```

**Why:** 
- Explicit column targeting prevents ambiguity
- Comments make it clear which column is being tested
- Easier to maintain when columns are added/removed

### 2. Avoid Chaining `.first()` and `.nth()` with Text Matching

**Bad:**
```javascript
await expect(row.getByText('4 techniques').first()).toBeVisible()
await expect(row.getByText('4 techniques').nth(1)).toBeVisible()
```

**Why:** When multiple elements have the same text, `.first()` and `.nth()` become non-deterministic and fragile.

**Good:**
```javascript
await expect(cells.nth(0)).toHaveText('4 techniques')
await expect(cells.nth(2)).toHaveText('4 techniques')
```

### 3. Use Semantic Selectors When Possible

**Priority order:**
1. `getByRole()` - Best for accessibility
2. `getByLabel()` - Good for forms
3. `getByTestId()` - Explicit test hooks
4. `locator()` with specific classes and `hasText` - For precise targeting
5. Generic `locator()` - Last resort

```javascript
// Best
await page.getByRole('button', { name: 'Submit' }).click()

// Good
await page.getByLabel('Email').fill('test@example.com')

// Acceptable
await page.getByTestId('submit-button').click()

// Last resort
await page.locator('.submit-btn').click()
```

---

## Text Matching

### 1. Use Class-Based Selectors with `hasText` for Precise Matching

**Bad:**
```javascript
await expect(cell.getByText('Input Capture')).toBeVisible()
// Matches: "Input Capture", "GUI Input Capture", "Input Capture Tool", etc.
```

**Better:**
```javascript
await expect(cell.getByText('Input Capture', { exact: true })).toBeVisible()
// Matches: "Input Capture" ONLY
```

**Best:**
```javascript
// Use specific class selector with hasText for precise targeting
await expect(cell.locator('.technique-name', { hasText: 'Input Capture' })).toBeVisible()
// Matches only elements with class 'technique-name' containing 'Input Capture'
```

**Why:** 
- `{ exact: true }` prevents substring matching but still searches all elements
- Class-based selectors with `hasText` combine structural and text matching
- More resilient to HTML changes while remaining precise

### 2. Match Exact HTML Content

**Bad:**
```javascript
await expect(page.getByText('Compromise Software Dependencies')).toBeVisible()
// HTML has: "Compromise Software Dependencies (NPM Sept 2025)"
```

**Good:**
```javascript
await expect(page.getByText('Compromise Software Dependencies (NPM Sept 2025)')).toBeVisible()
```

**Why:** Tests should match what's actually in the HTML. Partial matches can be fragile.

### 3. Use Regex for Flexible Matching

When exact text varies but pattern is consistent:

```javascript
await expect(page.getByText(/\d+ techniques/)).toBeVisible()  // Matches "4 techniques", "9 techniques", etc.
await expect(page.getByText(/Version \d+\.\d+/)).toBeVisible()  // Matches "Version 1.0", "Version 2.3", etc.
```

### 4. Combine Class Selectors with Text for Precision

**When you have nested elements with similar text:**

```javascript
// Bad - might match wrong element
await expect(cell.getByText('Input Capture', { exact: true })).toBeVisible()

// Good - targets specific element type
await expect(cell.locator('.technique-name', { hasText: 'Input Capture' })).toBeVisible()
await expect(cell.locator('.sub-technique-name', { hasText: 'GUI Input Capture' })).toBeVisible()
```

**Why:** This approach combines structural (class) and content (text) matching for maximum precision

---

## Assertions

### 1. Use Appropriate Assertion Methods

**For text content:**
```javascript
await expect(element).toHaveText('Expected text')           // Exact match
await expect(element).toContainText('partial')              // Substring match
```

**For counts:**
```javascript
await expect(items).toHaveCount(5)                          // Exact count
await expect(items.count()).toBeGreaterThanOrEqual(5)       // Minimum count
await expect(items.count()).toBeLessThanOrEqual(10)         // Maximum count
```

**For visibility:**
```javascript
await expect(element).toBeVisible()                         // Element is visible
await expect(element).toBeHidden()                          // Element is hidden
await expect(element).toBeAttached()                        // Element exists in DOM
```

### 2. Avoid Over-Specific Assertions

**Bad:**
```javascript
await expect(stats).toHaveText('380,000 victims')  // Breaks if formatting changes
```

**Good:**
```javascript
await expect(stats).toContainText('380')           // More resilient
await expect(stats).toContainText('victims')
```

---

## Table and Grid Testing

### 1. Always Use Index-Based Column Selection

**Bad:**
```javascript
const cells = row.locator('td')
await expect(cells.first()).toHaveText('Value')
```

**Good:**
```javascript
const cells = row.locator('td')
await expect(cells.nth(0)).toHaveText('Value')  // Column 0
await expect(cells.nth(1)).toHaveText('Other')  // Column 1
```

### 2. Verify Table Structure First

```javascript
// Verify correct number of columns
const headerCells = table.locator('thead tr th')
await expect(headerCells).toHaveCount(12)

// Verify correct number of rows
const bodyRows = table.locator('tbody tr')
await expect(bodyRows.count()).toBeGreaterThanOrEqual(1)
```

### 3. Add Comments for Column Indices

```javascript
// MITRE ATT&CK Matrix columns (0-indexed)
await expect(cells.nth(0)).toHaveText('4 techniques')   // Initial Access
await expect(cells.nth(1)).toHaveText('1 technique')    // Execution
await expect(cells.nth(2)).toHaveText('4 techniques')   // Persistence
// ... etc
```

---

## Common Pitfalls

### 1. Duplicate Text Values

**Problem:** Multiple elements have the same text.

**Bad:**
```javascript
await expect(page.getByText('4 techniques').first()).toBeVisible()
```

**Good:**
```javascript
await expect(cells.nth(0)).toHaveText('4 techniques')  // Specific column
```

### 2. Substring Matching

**Problem:** Text matches unintended elements.

**Bad:**
```javascript
await expect(page.getByText('Input')).toBeVisible()
// Matches: "Input", "Input Capture", "GUI Input", "Input Field", etc.
```

**Good:**
```javascript
await expect(page.getByText('Input', { exact: true })).toBeVisible()
```

### 3. Timing Issues

**Problem:** Element not ready when test runs.

**Bad:**
```javascript
const element = page.locator('.dynamic-content')
expect(await element.textContent()).toBe('Loaded')
```

**Good:**
```javascript
await expect(page.locator('.dynamic-content')).toHaveText('Loaded')
// Playwright auto-waits for element to be ready
```

### 4. Brittle Selectors

**Problem:** Tests break when HTML structure changes slightly.

**Bad:**
```javascript
await page.locator('div > div > div > span.text').click()
```

**Good:**
```javascript
await page.getByRole('button', { name: 'Submit' }).click()
await page.getByTestId('submit-button').click()
```

### 5. Hard-Coded Waits

**Problem:** Using `waitForTimeout()` makes tests slow and unreliable.

**Bad:**
```javascript
await page.waitForTimeout(500)  // Arbitrary wait
await scrollTopButton.click()
await page.waitForTimeout(1000)  // Hope scroll completes
```

**Good:**
```javascript
// Create a helper function for complex waits
async function waitForScrollComplete(page, targetSectionId = null, timeout = 2000) {
  await page.waitForFunction(
    () => {
      return new Promise(resolve => {
        const initialScroll = window.pageYOffset
        setTimeout(() => {
          resolve(window.pageYOffset === initialScroll)
        }, 100)
      })
    },
    { timeout }
  )
}

// Use it
await scrollTopButton.click()
await waitForScrollComplete(page)
```

**Why:** Waiting for actual conditions is more reliable than arbitrary timeouts.

### 6. Type Safety Issues

**Problem:** TypeScript errors from missing type annotations.

**Bad:**
```javascript
let consoleLogText = null  // Type is 'null', can't assign string later
consoleLogText = msg.text()  // TypeScript error
```

**Good:**
```javascript
/** @type {string | null} */
let consoleLogText = null  // Explicitly typed
consoleLogText = msg.text()  // No error
```

**Why:** Proper type annotations prevent TypeScript errors and make code more maintainable.

### 7. Type Checking in Evaluate Functions

**Problem:** Assuming element types in `evaluate()` callbacks.

**Bad:**
```javascript
const width = await element.evaluate(el => el.offsetWidth)
// Error: offsetWidth doesn't exist on SVGElement
```

**Good:**
```javascript
const width = await element.evaluate((el) => {
  if (el instanceof HTMLElement) {
    return el.offsetWidth
  }
  return 0
})
```

**Why:** Elements can be HTML or SVG. Type checking prevents runtime errors

---

## Helper Functions

### Create Reusable Wait Helpers

For complex wait conditions, create helper functions:

```javascript
/**
 * Waits for smooth scroll animation to complete
 * @param {import('@playwright/test').Page} page - Playwright page object
 * @param {string | null} targetSectionId - Optional: ID of target section to wait for
 * @param {number} timeout - Maximum time to wait (default: 2000ms)
 */
async function waitForScrollComplete(page, targetSectionId = null, timeout = 2000) {
  // Wait for scroll position to stabilize
  await page.waitForFunction(
    () => {
      return new Promise(resolve => {
        const initialScroll = window.pageYOffset
        setTimeout(() => {
          resolve(window.pageYOffset === initialScroll)
        }, 100)
      })
    },
    { timeout }
  )

  // Optionally wait for target section to be in viewport
  if (targetSectionId) {
    await page.waitForFunction(
      sectionId => {
        const element = document.getElementById(sectionId)
        if (!element) return false
        const rect = element.getBoundingClientRect()
        return rect.top >= 0 && rect.top < window.innerHeight * 0.8
      },
      targetSectionId,
      { timeout }
    )
  }
}
```

**Usage:**
```javascript
await overviewLink.click()
await waitForScrollComplete(page, 'overview')
await expect(overviewSection).toBeVisible()
```

---

## Testing Checklist

Before submitting a test, verify:

- [ ] Selectors are explicit and well-commented
- [ ] No use of `.first()` or `.nth()` with text matching
- [ ] Class-based selectors with `hasText` used for precise matching
- [ ] Counts use `>=` instead of `==` unless exact count is critical
- [ ] Table columns selected by index with comments
- [ ] Tests verify behavior, not implementation details
- [ ] No hard-coded waits (`page.waitForTimeout()`) - use helper functions instead
- [ ] Proper timeout options added for slow-loading elements
- [ ] TypeScript type annotations added where needed
- [ ] Type checking in `evaluate()` callbacks
- [ ] Wait for elements to be visible before interacting
- [ ] Tests are readable by someone unfamiliar with the code

---

## Examples from This Project

### Good Example: Index-Based Table Testing

```javascript
test('should display technique counts correctly', async ({ page }) => {
  const matrixTable = page.locator('.attack-matrix')
  const countRow = matrixTable.locator('thead tr').nth(1)
  const countCells = countRow.locator('td')
  
  // Verify we have exactly 12 tactic columns (MITRE ATT&CK standard)
  await expect(countCells).toHaveCount(12)

  // Use index-based selectors for reliable testing
  await expect(countCells.nth(0)).toHaveText('4 techniques')  // Initial Access
  await expect(countCells.nth(1)).toHaveText('1 technique')   // Execution
  await expect(countCells.nth(2)).toHaveText('4 techniques')  // Persistence
  // ... etc for all 12 columns
})
```

### Good Example: Class-Based Selectors with hasText

```javascript
test('should display techniques correctly', async ({ page }) => {
  const collectionCell = matrixTable.locator('tbody tr td').nth(8)
  
  // Wait for content to load
  await collectionCell.waitFor({ state: 'visible' })
  
  // Use class-based selector with hasText for precision
  await expect(collectionCell.locator('.technique-name', { hasText: 'Input Capture' })).toBeVisible()
  await expect(collectionCell.locator('.sub-technique-name', { hasText: 'GUI Input Capture' })).toBeVisible()
  
  // Allow substring matching when text may have additional details
  await expect(initialAccessCell.getByText('Compromise Software Dependencies')).toBeVisible()
})
```

### Good Example: Proper Wait Strategies

```javascript
test('should have smooth scrolling navigation', async ({ page }) => {
  // Wait for navigation to load
  await page.waitForSelector('nav', { state: 'visible' })
  
  const overviewLink = page.getByRole('link', { name: 'Overview' })
  await expect(overviewLink).toBeVisible({ timeout: 10000 })
  await overviewLink.click()
  
  // Use helper function instead of hard-coded wait
  await waitForScrollComplete(page, 'overview')
  
  const overviewSection = page.locator('#overview')
  await expect(overviewSection).toBeVisible({ timeout: 10000 })
})
```

### Good Example: Type-Safe Evaluate Functions

```javascript
test('should have correct table width', async ({ page }) => {
  const matrixTable = page.locator('.attack-matrix')
  
  // Type check before accessing HTMLElement properties
  const tableWidth = await matrixTable.evaluate((el) => {
    if (el instanceof HTMLElement) {
      return el.offsetWidth
    }
    return 0
  })
  
  expect(tableWidth).toBeGreaterThan(1500)
})
```

---

## Resources

- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
- [Playwright Locators](https://playwright.dev/docs/locators)
- [Playwright Assertions](https://playwright.dev/docs/test-assertions)

---

## Contributing

When you discover a new pattern or pitfall, please add it to this document!

**Last Updated:** December 2025 
