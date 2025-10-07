// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('E-Skimming Lab - Obfuscated Base64 Variant', () => {

  test.beforeEach(async ({ page }) => {
    // Enable console logging to capture skimmer logs
    page.on('console', msg => {
      if (msg.text().includes('[SKIMMER]')) {
        console.log('🔍 SKIMMER LOG:', msg.text());
      }
    });

    // Capture network requests to C2 server
    page.on('request', request => {
      if (request.url().includes('localhost:3000/collect')) {
        console.log('🌐 REQUEST TO C2:', {
          url: request.url(),
          method: request.method(),
          headers: request.headers(),
          postData: request.postData()
        });
      }
    });

    page.on('response', response => {
      if (response.url().includes('localhost:3000/collect')) {
        console.log('📥 RESPONSE FROM C2:', {
          url: response.url(),
          status: response.status(),
          headers: response.headers()
        });
      }
    });
  });

  test('should work identically to base variant despite obfuscation', async ({ page }) => {
    console.log('🚀 Testing obfuscated Base64 variant...');

    // Navigate to variant checkout page
    await page.goto('/checkout.html', {
      baseURL: 'http://localhost:8080'
    });
    await expect(page).toHaveTitle(/TechGear Store/);

    // Verify we're on checkout page
    await expect(page.locator('h2')).toContainText('Secure Checkout');

    // Fill out the form with test data
    console.log('📝 Filling out checkout form...');

    // Payment Information - using valid card number
    await page.fill('#card-number', '4000000000000002');
    await page.fill('#cardholder-name', 'Base64 Test User');
    await page.fill('#expiry', '12/28');
    await page.fill('#cvv', '123');

    // Billing Information
    await page.fill('#email', 'base64test@example.com');
    await page.fill('#billing-address', '123 Obfuscated Street');
    await page.fill('#city', 'Base64 City');
    await page.fill('#zip', '12345');
    await page.selectOption('#country', 'US');
    await page.fill('#phone', '+1 (555) 999-0001');

    console.log('✅ Form filled, submitting...');

    // Submit the form
    await page.click('button[type="submit"]');

    // Wait for success message - same behavior as base variant
    await expect(page.locator('#success-message')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('#success-message')).toContainText('Order Placed Successfully');

    console.log('✅ Form submitted successfully - obfuscation did not break functionality');

    // Wait a bit for skimmer to process
    await page.waitForTimeout(2000);

    console.log('🔍 Test completed - obfuscated skimmer should have same behavior as base');
  });

  test('should contain Base64 obfuscation patterns', async ({ page }) => {
    console.log('🔍 Analyzing obfuscation patterns...');

    // Navigate to variant checkout page
    await page.goto('/checkout.html', {
      baseURL: 'http://localhost:8080'
    });

    // Check for obfuscation patterns in the page source
    const content = await page.content();

    // Verify presence of Base64 obfuscation markers
    console.log('📊 Checking for obfuscation patterns...');

    // Check for atob() calls (Base64 decoding)
    const hasAtobCalls = content.includes('atob(');
    console.log('✓ atob() calls found:', hasAtobCalls);
    expect(hasAtobCalls).toBe(true);

    // Check for Base64 encoded strings
    const hasBase64Strings = /atob\('[A-Za-z0-9+/=]+'\)/.test(content);
    console.log('✓ Base64 encoded strings found:', hasBase64Strings);
    expect(hasBase64Strings).toBe(true);

    // Check for variable name mangling (single letter variables)
    const hasMangledVars = /var [a-z];/.test(content);
    console.log('✓ Mangled variable names found:', hasMangledVars);
    expect(hasMangledVars).toBe(true);

    // Check for debugger statement (anti-debugging)
    const hasDebugger = content.includes('debugger;');
    console.log('✓ Anti-debugging code found:', hasDebugger);
    expect(hasDebugger).toBe(true);

    // Check for dynamic property access
    const hasDynamicAccess = content.includes('window[');
    console.log('✓ Dynamic property access found:', hasDynamicAccess);
    expect(hasDynamicAccess).toBe(true);

    console.log('✅ All obfuscation patterns detected successfully');
  });

  test('should capture same data as base variant', async ({ page }) => {
    const networkRequests = [];

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

    // Navigate and submit
    await page.goto('/checkout.html', {
      baseURL: 'http://localhost:8080'
    });

    await page.fill('#card-number', '5555555555554444');
    await page.fill('#cardholder-name', 'Obfuscated Test');
    await page.fill('#expiry', '03/27');
    await page.fill('#cvv', '789');
    await page.fill('#email', 'obfuscated@test.com');
    await page.fill('#billing-address', '789 Hidden St');
    await page.fill('#city', 'Secret City');
    await page.fill('#zip', '54321');

    await page.click('button[type="submit"]');
    await page.waitForTimeout(3000);

    console.log('🌐 Network requests captured:', networkRequests.length);

    networkRequests.forEach(req => {
      console.log('📡 Request:', {
        url: req.url,
        method: req.method,
        hasPostData: !!req.postData,
        postDataLength: req.postData ? req.postData.length : 0
      });

      if (req.postData) {
        try {
          const data = JSON.parse(req.postData);
          console.log('💳 Captured card data:', {
            cardNumber: data.cardNumber ? '****' + data.cardNumber.slice(-4) : 'missing',
            hasMetadata: !!data.metadata,
            fieldCount: Object.keys(data).length
          });
        } catch (e) {
          console.log('❌ Could not parse POST data');
        }
      }
    });

    // Verify network request was made despite obfuscation
    expect(networkRequests.length).toBeGreaterThan(0);
  });
});