# E-Skimming Labs Test Suite

This directory contains Playwright tests for the E-Skimming Labs platform, focusing on testing the MITRE ATT&CK Matrix page and other core functionality.

## Test Structure

### MITRE ATT&CK Matrix Tests (`mitre-attack-matrix.spec.js`)

Comprehensive tests for the MITRE ATT&CK Matrix page including:

#### Back Button Functionality
- ✅ Back button visibility and correct URL setting
- ✅ Environment-aware URL detection (localhost, staging, production)
- ✅ Navigation back to labs homepage
- ✅ Console logging verification

#### Matrix Table Structure
- ✅ Correct number of columns (12 MITRE ATT&CK tactics)
- ✅ All tactic headers present and correctly labeled
- ✅ Technique counts displayed accurately
- ✅ Techniques and sub-techniques properly formatted
- ✅ Horizontal scrolling functionality
- ✅ Responsive design for mobile devices

#### UI Components
- ✅ Navigation menu functionality
- ✅ Smooth scrolling between sections
- ✅ Statistics cards display
- ✅ Expandable sections functionality
- ✅ Scroll-to-top button
- ✅ Footer content verification

## Running Tests

### Prerequisites
1. Ensure the labs-home service is running:
   ```bash
   cd /path/to/e-skimming-labs
   ./docker-labs.sh start home-index
   ```

2. Install test dependencies:
   ```bash
   cd test
   npm install
   ```

### Test Commands

```bash
# Run all tests
npm test

# Run tests in headed mode (visible browser)
npm run test:headed

# Run tests in debug mode
npm run test:debug

# Run tests with UI mode
npm run test:ui

# Run only MITRE ATT&CK matrix tests
npm run test:mitre

# Run MITRE tests in headed mode
npm run test:mitre:headed

# Run tests on specific browsers/devices
npm run test:chrome          # Desktop Chrome only
npm run test:mobile          # Mobile Chrome (Pixel 5)
npm run test:tablet          # Tablet Chrome (iPad Pro)

# Run MITRE tests on specific devices
npm run test:mitre:chrome    # MITRE tests on Desktop Chrome
npm run test:mitre:mobile    # MITRE tests on Mobile Chrome
npm run test:mitre:tablet    # MITRE tests on Tablet Chrome

# View test report
npm run test:report
```

## Test Coverage

### Back Button Tests
- **Environment Detection**: Tests that the JavaScript correctly detects the environment (localhost, staging, production) and sets the appropriate URL
- **URL Verification**: Confirms the back button href is set correctly for each environment
- **Navigation**: Tests that clicking the back button navigates to the correct page
- **Console Logging**: Verifies that environment detection is logged to console

### Matrix Table Tests
- **Column Count**: Verifies exactly 12 columns (one for each MITRE ATT&CK tactic)
- **Tactic Headers**: Confirms all expected tactic names are present
- **Technique Counts**: Validates the technique count row shows correct numbers
- **Technique Display**: Tests that techniques and sub-techniques are properly formatted
- **Scrolling**: Ensures horizontal scrolling works for the wide table
- **Responsive Design**: Tests mobile viewport compatibility

### UI/UX Tests
- **Navigation**: Tests all navigation links work correctly
- **Smooth Scrolling**: Verifies section navigation works smoothly
- **Interactive Elements**: Tests expandable sections, scroll-to-top, etc.
- **Content Verification**: Ensures all expected content is displayed

## Browser Support

Tests run on:
- ✅ Chromium (Desktop Chrome)
- ✅ Chrome Mobile (Pixel 5)
- ✅ Chrome Tablet (iPad Pro)

## Test Environment

- **Base URL**: `http://localhost:8080`
- **Target Page**: `/mitre-attack`
- **Timeout**: 10 seconds for actions and navigation
- **Screenshots**: Captured on failure
- **Videos**: Recorded on failure
- **Traces**: Collected on retry

## Continuous Integration

The tests are designed to work in CI environments:
- Retries: 2 attempts on CI
- Workers: 1 on CI (parallel disabled)
- Server startup: Automatically starts required services
- Timeout: Extended for CI environments

## Debugging

### Common Issues

1. **Service Not Running**: Ensure `home-index` service is running on port 8080
2. **Timeout Errors**: Check if the service is responding at `http://localhost:8080`
3. **Element Not Found**: Verify the page has loaded completely with `waitForLoadState('networkidle')`

### Debug Commands

```bash
# Run specific test in debug mode
npx playwright test mitre-attack-matrix.spec.js --debug

# Run with trace
npx playwright test --trace on

# Run with video
npx playwright test --video on
```

## Test Data

The tests verify specific content:
- **Technique IDs**: T1190, T1078, T1195, T1059.007, etc.
- **Technique Names**: "Exploit Public-Facing Application", "Valid Accounts", etc.
- **Statistics**: 380K victims, £20M fine, 11K+ sites, 13+ groups
- **URLs**: Environment-specific back button URLs

## Contributing

When adding new tests:
1. Follow the existing test structure
2. Use descriptive test names
3. Include both positive and negative test cases
4. Add appropriate waits and assertions
5. Update this README with new test coverage
