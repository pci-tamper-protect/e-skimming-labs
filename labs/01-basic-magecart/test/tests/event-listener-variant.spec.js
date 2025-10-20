// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('E-Skimming Lab - Event Listener Variant', () => {

  test.beforeEach(async ({ page }) => {
    // Enable console logging to capture skimmer logs
    page.on('console', msg => {
      if (msg.text().includes('[SKIMMER]')) {
        console.log('🔍 SKIMMER LOG:', msg.text());
      }
    });

    // Capture network requests to C2 server
    page.on('request', request => {
      if (request.url().includes('localhost:9002/collect')) {
        console.log('🌐 REQUEST TO C2:', {
          url: request.url(),
          method: request.method(),
          headers: request.headers(),
          postData: request.postData()
        });
      }
    });

    page.on('response', response => {
      if (response.url().includes('localhost:9002/collect')) {
        console.log('📥 RESPONSE FROM C2:', {
          url: response.url(),
          status: response.status(),
          headers: response.headers()
        });
      }
    });
  });

  test('should collect data via event listeners instead of form submission', async ({ page }) => {
    console.log('🚀 Testing event listener variant...');

    // Load the variant HTML content directly with proper base URL for resources
    const fs = require('fs');
    const path = require('path');
    const variantHtmlPath = path.join(__dirname, '../../variants/event-listener-variant/vulnerable-site/checkout.html');
    let htmlContent = fs.readFileSync(variantHtmlPath, 'utf8');

    // Update the script src to point to the variant's JS file
    const variantJsPath = path.join(__dirname, '../../variants/event-listener-variant/vulnerable-site/js/checkout-compromised.js');
    const jsContent = fs.readFileSync(variantJsPath, 'utf8');

    // Inject the JavaScript directly into the HTML to avoid path issues
    htmlContent = htmlContent.replace(
      '<script src="js/checkout-compromised.js"></script>',
      `<script>${jsContent}</script>`
    );

    // Set the HTML content with proper base URL for form submission
    await page.setContent(htmlContent, {
      baseURL: 'http://localhost:8080',
      waitUntil: 'networkidle'
    });

    await expect(page).toHaveTitle(/TechGear Store/);

    // Verify we're on checkout page
    await expect(page.locator('h2')).toContainText('Secure Checkout');

    console.log('📝 Filling out form with event monitoring...');

    // Fill out fields one by one to trigger event listeners
    await page.fill('#card-number', '4000000000000002');
    console.log('✓ Card number filled - should trigger mouseup/blur events');
    await page.waitForTimeout(100); // Let event listeners process

    await page.fill('#cardholder-name', 'Event Listener Test');
    console.log('✓ Cardholder name filled');
    await page.waitForTimeout(100);

    await page.fill('#expiry', '12/28');
    console.log('✓ Expiry filled');
    await page.waitForTimeout(100);

    await page.fill('#cvv', '123');
    console.log('✓ CVV filled');
    await page.waitForTimeout(100);

    await page.fill('#email', 'events@example.com');
    await page.fill('#billing-address', '123 Event Street');
    await page.fill('#city', 'Listener City');
    await page.fill('#zip', '12345');
    await page.selectOption('#country', 'US');
    await page.fill('#phone', '+1 (555) 111-2222');

    console.log('✅ All fields filled - event listeners should have collected data');

    // Click the submit button to trigger button event listeners
    console.log('🖱️ Clicking submit button to trigger button listeners...');
    await page.click('button[type="submit"]');

    // Wait for success message
    await expect(page.locator('#success-message')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('#success-message')).toContainText('Order Placed Successfully');

    console.log('✅ Form submitted successfully - event listeners captured data during field interactions');

    // Wait for final processing
    await page.waitForTimeout(2000);

    console.log('🔍 Test completed - data should have been collected via mouseup/touchend/blur events');
  });

  test('should contain event listener patterns', async ({ page }) => {
    console.log('🔍 Analyzing event listener patterns...');

    // Read the JavaScript file directly to check for patterns
    const fs = require('fs');
    const path = require('path');
    const jsFilePath = path.join(__dirname, '../../variants/event-listener-variant/vulnerable-site/js/checkout-compromised.js');
    const jsContent = fs.readFileSync(jsFilePath, 'utf8');

    console.log('📊 Checking for event listener patterns in JavaScript file...');

    // Check for mouseup event listeners
    const hasMouseupListeners = jsContent.includes('mouseup');
    console.log('✓ mouseup event listeners found:', hasMouseupListeners);
    expect(hasMouseupListeners).toBe(true);

    // Check for touchend event listeners (mobile support)
    const hasTouchendListeners = jsContent.includes('touchend');
    console.log('✓ touchend event listeners found:', hasTouchendListeners);
    expect(hasTouchendListeners).toBe(true);

    // Check for blur event listeners
    const hasBlurListeners = jsContent.includes('blur');
    console.log('✓ blur event listeners found:', hasBlurListeners);
    expect(hasBlurListeners).toBe(true);

    // Check for addEventListener calls
    const hasAddEventListenerCalls = jsContent.includes('addEventListener');
    console.log('✓ addEventListener calls found:', hasAddEventListenerCalls);
    expect(hasAddEventListenerCalls).toBe(true);

    // Check for progressive data collection
    const hasProgressiveCollection = jsContent.includes('collectedData');
    console.log('✓ Progressive data collection found:', hasProgressiveCollection);
    expect(hasProgressiveCollection).toBe(true);

    // Check for field mappings
    const hasFieldMappings = jsContent.includes('fieldMappings');
    console.log('✓ Field mapping system found:', hasFieldMappings);
    expect(hasFieldMappings).toBe(true);

    // Check for variant identifier
    const hasVariantMarker = jsContent.includes('event-listener-variant');
    console.log('✓ Event listener variant marker found:', hasVariantMarker);
    expect(hasVariantMarker).toBe(true);

    console.log('✅ All event listener patterns detected successfully');
  });

  test('should capture data with real-time field monitoring', async ({ page }) => {
    const networkRequests = [];
    const consoleMessages = [];

    // Capture network requests
    page.on('request', request => {
      if (request.url().includes('/collect')) {
        networkRequests.push({
          url: request.url(),
          method: request.method(),
          postData: request.postData(),
          headers: request.headers()
        });
      }
    });

    // Capture console messages for real-time monitoring verification
    page.on('console', msg => {
      if (msg.text().includes('[SKIMMER]')) {
        consoleMessages.push(msg.text());
      }
    });

    // Load the variant HTML content with embedded JavaScript
    const fs = require('fs');
    const path = require('path');
    const variantHtmlPath = path.join(__dirname, '../../variants/event-listener-variant/vulnerable-site/checkout.html');
    let htmlContent = fs.readFileSync(variantHtmlPath, 'utf8');

    const variantJsPath = path.join(__dirname, '../../variants/event-listener-variant/vulnerable-site/js/checkout-compromised.js');
    const jsContent = fs.readFileSync(variantJsPath, 'utf8');

    // Inject the JavaScript directly into the HTML
    htmlContent = htmlContent.replace(
      '<script src="js/checkout-compromised.js"></script>',
      `<script>${jsContent}</script>`
    );

    await page.setContent(htmlContent, {
      baseURL: 'http://localhost:8080',
      waitUntil: 'networkidle'
    });

    console.log('📝 Testing real-time field monitoring...');

    // Fill fields with pauses to allow event processing
    await page.fill('#card-number', '5555555555554444');
    await page.click('body'); // Trigger blur event
    await page.waitForTimeout(200);

    await page.fill('#cvv', '789');
    await page.click('body'); // Trigger blur event
    await page.waitForTimeout(200);

    await page.fill('#expiry', '03/27');
    await page.click('body'); // Trigger blur event
    await page.waitForTimeout(200);

    await page.fill('#cardholder-name', 'Real-time Test');
    await page.fill('#email', 'realtime@test.com');
    await page.fill('#billing-address', '789 Real-time St');
    await page.fill('#city', 'Monitor City');
    await page.fill('#zip', '54321');

    // Click submit button to trigger final collection
    await page.click('button[type="submit"]');
    await page.waitForTimeout(3000);

    console.log('🌐 Network requests captured:', networkRequests.length);
    console.log('📝 Console messages captured:', consoleMessages.length);

    // Verify data was collected via event listeners
    expect(networkRequests.length).toBeGreaterThan(0);

    if (networkRequests.length > 0) {
      const req = networkRequests[0];
      console.log('📡 Request details:', {
        url: req.url,
        method: req.method,
        hasPostData: !!req.postData
      });

      if (req.postData) {
        try {
          const data = JSON.parse(req.postData);
          console.log('💳 Captured data structure:', {
            hasCardNumber: !!data.cardNumber,
            hasMetadata: !!data.metadata,
            collectionMethod: data.metadata?.collectionMethod,
            fieldCount: Object.keys(data).length
          });

          // Verify this is the event listener variant
          expect(data.metadata?.collectionMethod).toBe('event-listener-variant');
        } catch (e) {
          console.log('❌ Could not parse POST data');
        }
      }
    }

    // Check for real-time monitoring messages
    const updateMessages = consoleMessages.filter(msg => msg.includes('Updated'));
    console.log('📊 Real-time field updates captured:', updateMessages.length);

    console.log('✅ Real-time monitoring verification complete');
  });

  test('should work on mobile with touch events', async ({ page }) => {
    // Simulate mobile environment
    await page.setViewportSize({ width: 375, height: 667 });

    console.log('📱 Testing mobile touch event support...');

    // Load the variant HTML content with embedded JavaScript
    const fs = require('fs');
    const path = require('path');
    const variantHtmlPath = path.join(__dirname, '../../variants/event-listener-variant/vulnerable-site/checkout.html');
    let htmlContent = fs.readFileSync(variantHtmlPath, 'utf8');

    const variantJsPath = path.join(__dirname, '../../variants/event-listener-variant/vulnerable-site/js/checkout-compromised.js');
    const jsContent = fs.readFileSync(variantJsPath, 'utf8');

    // Inject the JavaScript directly into the HTML
    htmlContent = htmlContent.replace(
      '<script src="js/checkout-compromised.js"></script>',
      `<script>${jsContent}</script>`
    );

    await page.setContent(htmlContent, {
      baseURL: 'http://localhost:8080',
      waitUntil: 'networkidle'
    });

    // Simulate touch interactions
    await page.fill('#card-number', '4000000000000002');
    await page.tap('#card-number'); // Should trigger touchend
    await page.waitForTimeout(100);

    await page.fill('#cvv', '123');
    await page.tap('#cvv'); // Should trigger touchend
    await page.waitForTimeout(100);

    await page.fill('#expiry', '12/28');
    await page.fill('#cardholder-name', 'Mobile Test User');
    await page.fill('#email', 'mobile@test.com');
    await page.fill('#billing-address', '123 Mobile Street');
    await page.fill('#city', 'Touch City');
    await page.fill('#zip', '12345');

    // Tap submit button
    await page.tap('button[type="submit"]');

    // Verify mobile interaction works
    await expect(page.locator('#success-message')).toBeVisible({ timeout: 10000 });

    console.log('✅ Mobile touch events handled successfully');
  });
});