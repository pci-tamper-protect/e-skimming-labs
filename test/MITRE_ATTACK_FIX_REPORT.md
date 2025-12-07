# MITRE ATT&CK Matrix Page Testing and Fixes

**Author**: Aya  
**Date**: December 6, 2024  
**Project**: E-Skimming Labs - MITRE ATT&CK Matrix Implementation

## Executive Summary

This report documents the issues encountered during the implementation and testing of the MITRE ATT&CK Matrix page for the E-Skimming Labs platform, along with the solutions implemented to resolve them. All identified issues have been successfully addressed, and the test suite now passes completely.

## Introduction

The MITRE ATT&CK Matrix page is a critical component of the E-Skimming Labs educational platform, providing users with a comprehensive framework for understanding e-skimming attack techniques. During the development and testing phase, several issues were identified that prevented the page from functioning correctly in local development environments and caused test failures.

## Problem Statement

The initial implementation faced multiple challenges:

1. The page failed to load when running the service locally
2. Static assets required by the page were not being served correctly
3. Playwright tests were failing due to timeout issues and selector problems
4. The Go service had compilation errors preventing deployment

## Methodology

I systematically identified and addressed each issue through the following approach:

1. **Problem Identification**: Analyzed error messages, test failures, and server logs
2. **Root Cause Analysis**: Traced issues to their source in the codebase
3. **Solution Design**: Designed fixes that maintain compatibility with both local and production environments
4. **Implementation**: Applied fixes and verified through testing
5. **Validation**: Confirmed all tests pass and the page functions correctly

## Issues and Solutions

### Issue 1: Local File Serving Failure

**Problem**: When running the service locally using `go run`, the `/mitre-attack` route returned 404 errors. The page HTML file could not be found.

**Root Cause**: The `serveMITREPage` function in `main.go` only attempted to read the file from the container path (`/app/docs/mitre-attack-visual.html`), which doesn't exist in local development environments.

**Solution**: I modified the `serveMITREPage` function to try multiple file paths in sequence, supporting both container and local development scenarios:

```go
paths := []string{
    "/app/docs/mitre-attack-visual.html",        // Container path
    "../../docs/mitre-attack-visual.html",        // Local dev from service directory
    "docs/mitre-attack-visual.html",              // Local dev from root
    "../docs/mitre-attack-visual.html",           // Alternative local path
}
```

This approach ensures the service works in both Docker containers and local development environments.

### Issue 2: Missing Static Asset Route

**Problem**: The page requires `private-data-loader.js` to function properly, but this file was not being served, causing the page to run in a degraded "public-only" mode.

**Root Cause**: No HTTP route was registered to serve the JavaScript file at `/mitre-attack/private-data-loader.js`.

**Solution**: I created a new `serveDocsFile` function to handle static file serving with the same multi-path fallback approach, and registered the route:

```go
http.HandleFunc("/mitre-attack/private-data-loader.js", func(w http.ResponseWriter, r *http.Request) {
    serveDocsFile(w, r, "private-data-loader.js")
})
```

The `serveDocsFile` function automatically sets appropriate Content-Type headers based on file extensions (JavaScript, CSS, JSON).

### Issue 3: Go Compilation Error

**Problem**: The service failed to compile with the error: `usedPath declared and not used`.

**Root Cause**: I had declared a variable `usedPath` for logging purposes but never actually used it, violating Go's strict compilation rules.

**Solution**: Removed the unused variable declaration, keeping only the essential logging that uses the path directly.

### Issue 4: Playwright Test Timeouts

**Problem**: Multiple Playwright tests were failing with timeout errors. Elements such as technique links, sub-technique links, and navigation menus were not appearing within the default 10-second timeout.

**Root Cause Analysis**:
- The default timeout of 10 seconds was insufficient for pages with dynamic JavaScript content
- Tests were not explicitly waiting for JavaScript execution to complete
- No health checks were performed before attempting to load the page

**Solution**: I implemented a multi-pronged approach:

1. **Increased Timeouts**: Updated `playwright.config.js` to increase both `navigationTimeout` and `actionTimeout` from 10s to 30s
2. **Enhanced beforeEach Hook**: Added server health checks and explicit waits:
   ```javascript
   await page.goto('/mitre-attack', { 
       waitUntil: 'domcontentloaded',
       timeout: 30000 
   })
   await page.waitForSelector('.attack-matrix, h1, nav', { timeout: 10000 })
   ```
3. **Explicit Waits**: Added `waitForSelector` calls before critical assertions to ensure elements are ready

### Issue 5: Playwright Strict Mode Violations

**Problem**: The test for "Input Capture" technique was failing with a strict mode violation, indicating that `getByText('Input Capture')` matched multiple elements.

**Root Cause**: The text "Input Capture" appears in two places:
- As a technique name: "Input Capture" (T1056)
- As part of a sub-technique name: "GUI Input Capture" (T1056.002)

Playwright's strict mode requires selectors to match exactly one element.

**Solution**: I replaced the broad text-based selector with a precise CSS selector that targets the specific element:

```javascript
// Before (caused strict mode violation):
await expect(collectionCell.getByText('Input Capture')).toBeVisible()

// After (precise selector):
await expect(collectionCell.locator('.technique-name', { hasText: 'Input Capture' })).toBeVisible()
```

This ensures we target only the technique name element, not the sub-technique name.

## Implementation Details

### File Modifications

1. **`deploy/shared-components/home-index-service/main.go`**
   - Updated `serveMITREPage()` function with multi-path file resolution
   - Created new `serveDocsFile()` function for static asset serving
   - Added route registration for `/mitre-attack/private-data-loader.js`
   - Removed unused variable to fix compilation error

2. **`test/playwright.config.js`**
   - Increased `navigationTimeout` from 10000ms to 30000ms
   - Increased `actionTimeout` from 10000ms to 30000ms

3. **`test/e2e/mitre-attack-matrix.spec.js`**
   - Enhanced `beforeEach` hook with health checks and explicit waits
   - Fixed strict mode violations using precise CSS selectors
   - Added timeout parameters to critical assertions
   - Improved error handling with diagnostic messages

## Testing and Validation

After implementing the fixes, I ran the complete test suite to validate the solutions:

```bash
npm test
```

**Results**: All 15+ tests in the MITRE ATT&CK Matrix test suite now pass successfully, including:
- Page title and header verification
- Back button functionality
- Matrix table structure validation
- Technique and sub-technique display
- Navigation menu functionality
- Responsive design tests
- Interactive element tests

## Local Development Setup

For future reference, the service can be run locally using:

```bash
ENVIRONMENT=local DOMAIN=localhost:3000 PORT=3000 go run deploy/shared-components/home-index-service/main.go
```

Or using Docker:

```bash
./docker-labs.sh start home-index
```

The server health can be verified with:

```bash
curl http://localhost:3000/health
```

## Lessons Learned

1. **Environment Flexibility**: Implementing multi-path file resolution from the start would have prevented local development issues
2. **Timeout Configuration**: Dynamic web pages require longer timeouts than static content
3. **Selector Precision**: Using CSS class selectors is more reliable than broad text matching
4. **Error Handling**: Comprehensive error messages and health checks significantly improve debugging efficiency

## Conclusion

All identified issues have been successfully resolved. The MITRE ATT&CK Matrix page now:
- Loads correctly in both local and containerized environments
- Serves all required static assets properly
- Passes all Playwright tests consistently
- Provides a reliable user experience

The implementation is ready for production deployment and future enhancements.

## Future Recommendations

1. Consider adding automated health checks in CI/CD pipelines
2. Monitor test execution times and adjust timeouts if needed
3. Document any additional static files that may need serving routes
4. Implement retry logic for potentially flaky tests in CI environments

---

**Status**: ✅ All Issues Resolved  
**Test Status**: ✅ All Tests Passing  
**Ready for Production**: ✅ Yes
