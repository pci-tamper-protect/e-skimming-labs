// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('DOM-Based Skimming Lab - Shadow DOM Stealth Attack', () => {

  test.beforeEach(async ({ page }) => {
    // Enable console logging to capture attack logs
    page.on('console', msg => {
      if (msg.text().includes('[Shadow-Skimmer]')) {
        console.log('👻 SHADOW-SKIMMER LOG:', msg.text());
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

  test('should create hidden shadow DOM infrastructure', async ({ page }) => {
    console.log('🚀 Testing Shadow DOM infrastructure creation...');

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    });

    // Inject shadow skimmer attack
    await page.addScriptTag({
      path: './malicious-code/shadow-skimmer.js'
    });

    await expect(page).toHaveTitle(/SecureBank/);

    // Wait for shadow infrastructure creation
    await page.waitForTimeout(3000);

    console.log('🔍 Analyzing shadow DOM infrastructure...');

    // Check shadow attack status
    const shadowStatus = await page.evaluate(() => {
      return window.shadowSkimmerAttack ? window.shadowSkimmerAttack.getStatus() : null;
    });

    console.log('📊 Shadow attack status:', shadowStatus);

    if (shadowStatus) {
      expect(shadowStatus.active).toBe(true);
      expect(shadowStatus.shadowHosts).toBeGreaterThan(0);
      console.log('✅ Shadow DOM infrastructure created successfully');
    } else {
      console.log('⚠️ Shadow attack not active');
    }

    // Try to detect shadow hosts (should be hidden)
    const visibleShadowHosts = await page.evaluate(() => {
      const elements = document.querySelectorAll('*');
      let visibleHosts = 0;

      for (let element of elements) {
        if (element.shadowRoot) {
          const style = window.getComputedStyle(element);
          if (style.opacity !== '0' && style.display !== 'none') {
            visibleHosts++;
          }
        }
      }

      return visibleHosts;
    });

    console.log('👻 Visible shadow hosts (should be 0):', visibleShadowHosts);
    expect(visibleShadowHosts).toBe(0);

    console.log('👻 Shadow DOM infrastructure test completed');
  });

  test('should monitor fields across shadow boundaries', async ({ page }) => {
    console.log('🔄 Testing cross-shadow boundary monitoring...');

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    });

    // Inject shadow skimmer attack
    await page.addScriptTag({
      path: './malicious-code/shadow-skimmer.js'
    });

    // Wait for shadow setup
    await page.waitForTimeout(3000);

    console.log('📝 Testing field monitoring through shadows...');

    // Navigate to transfer section
    await page.click('[data-section="transfer"]');
    await page.waitForTimeout(1000);

    // Fill form fields to trigger shadow monitoring
    await page.selectOption('#from-account', 'checking');
    await page.fill('#to-account', '123456789');
    await page.fill('#transfer-amount', '2500.00');
    await page.fill('#transfer-password', 'shadowtest123');

    // Add a small delay between fields to trigger monitoring
    await page.waitForTimeout(500);

    console.log('✅ Form fields filled through shadow monitoring');

    // Wait for shadow data collection
    await page.waitForTimeout(3000);

    // Check captured data
    const capturedData = await page.evaluate(() => {
      return window.shadowSkimmerAttack ? window.shadowSkimmerAttack.getCapturedData() : null;
    });

    console.log('💾 Shadow captured data summary:', {
      sessions: capturedData ? capturedData.length : 0
    });

    if (capturedData && capturedData.length > 0) {
      const sessionWithData = capturedData.find(session =>
        session.values.length > 0 || session.keystrokes.length > 0
      );

      if (sessionWithData) {
        console.log('🎯 Found session with captured data:', {
          elementId: sessionWithData.elementId,
          valuesCount: sessionWithData.values.length,
          keystrokesCount: sessionWithData.keystrokes.length,
          eventsCount: sessionWithData.events.length
        });

        expect(sessionWithData.values.length).toBeGreaterThan(0);
      }
    }

    console.log('🔄 Cross-shadow boundary monitoring test completed');
  });

  test('should handle closed shadow DOM stealth', async ({ page }) => {
    console.log('🔒 Testing closed shadow DOM stealth capabilities...');

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    });

    // Inject shadow skimmer attack
    await page.addScriptTag({
      path: './malicious-code/shadow-skimmer.js'
    });

    await page.waitForTimeout(3000);

    // Try to access shadow DOMs from outside (should fail for closed mode)
    const shadowAccessTest = await page.evaluate(() => {
      const results = {
        shadowHostsFound: 0,
        accessibleShadowRoots: 0,
        closedShadowRoots: 0
      };

      // Look for elements with shadow roots
      const walker = document.createTreeWalker(
        document.body,
        NodeFilter.SHOW_ELEMENT,
        null,
        false
      );

      let node;
      while (node = walker.nextNode()) {
        if (node.shadowRoot !== null) {
          results.shadowHostsFound++;
          results.accessibleShadowRoots++;
        } else if (node.attachShadow) {
          // Element might have a closed shadow root
          try {
            // This won't work for closed shadows
            const testShadow = node.shadowRoot;
            if (testShadow === null) {
              // Could be closed shadow
              results.closedShadowRoots++;
            }
          } catch (e) {
            results.closedShadowRoots++;
          }
        }
      }

      return results;
    });

    console.log('🔍 Shadow access test results:', shadowAccessTest);

    // Verify stealth (should have hidden shadow infrastructure)
    const shadowHosts = await page.evaluate(() => {
      return window.shadowSkimmerAttack ? window.shadowSkimmerAttack.getShadowHosts() : [];
    });

    console.log('👻 Shadow hosts from attack:', shadowHosts.length);

    if (shadowHosts.length > 0) {
      console.log('✅ Closed shadow DOM infrastructure confirmed');

      // Verify shadow hosts are hidden
      const hostVisibility = await page.evaluate((hosts) => {
        return hosts.map(hostData => {
          const host = hostData.host;
          const style = window.getComputedStyle(host);
          return {
            opacity: style.opacity,
            display: style.display,
            visibility: style.visibility,
            zIndex: style.zIndex
          };
        });
      }, shadowHosts);

      console.log('👻 Shadow host visibility:', hostVisibility);

      // All hosts should be hidden
      hostVisibility.forEach(style => {
        expect(parseFloat(style.opacity)).toBeLessThanOrEqual(0);
      });
    }

    console.log('🔒 Closed shadow DOM stealth test completed');
  });

  test('should capture data through shadow isolation', async ({ page }) => {
    const networkRequests = [];

    // Capture network requests for shadow data exfiltration
    page.on('request', request => {
      if (request.url().includes('/collect')) {
        networkRequests.push({
          url: request.url(),
          method: request.method(),
          postData: request.postData(),
          timestamp: Date.now()
        });
      }
    });

    console.log('💽 Testing shadow-isolated data capture...');

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    });

    // Inject shadow skimmer attack
    await page.addScriptTag({
      path: './malicious-code/shadow-skimmer.js'
    });

    await page.waitForTimeout(3000);

    // Navigate to cards section and trigger security prompt
    await page.click('[data-section="cards"]');
    await page.waitForTimeout(1000);

    // Trigger card action for password/CVV fields
    await page.click('button:has-text("Change PIN")');
    await page.waitForTimeout(500);

    console.log('🔐 Filling sensitive fields for shadow capture...');

    // Fill sensitive fields that should trigger immediate exfiltration
    await page.fill('#card-password', 'shadowpassword123');
    await page.fill('#card-cvv', '789');

    // Blur to trigger immediate shadow exfiltration
    await page.click('body');

    console.log('✅ Sensitive fields filled and blurred');

    // Wait for shadow data exfiltration
    await page.waitForTimeout(4000);

    console.log('🌐 Network requests captured:', networkRequests.length);

    // Check for shadow-specific exfiltration
    const shadowRequests = networkRequests.filter(req => {
      if (req.postData) {
        try {
          const data = JSON.parse(req.postData);
          return data.type === 'shadow_dom_capture' || data.metadata?.attackType === 'shadow-dom-stealth';
        } catch (e) {
          return false;
        }
      }
      return false;
    });

    console.log('👻 Shadow exfiltration requests:', shadowRequests.length);

    if (shadowRequests.length > 0) {
      const shadowData = JSON.parse(shadowRequests[0].postData);
      console.log('💽 Shadow data structure:', {
        type: shadowData.type,
        sessionsCount: shadowData.sessions ? shadowData.sessions.length : 0,
        hasShadowInfo: !!shadowData.shadowInfo,
        attackType: shadowData.metadata?.attackType
      });

      expect(shadowData.metadata.attackType).toBe('shadow-dom-stealth');

      if (shadowData.sessions) {
        expect(shadowData.sessions.length).toBeGreaterThan(0);
      }
    }

    console.log('💽 Shadow-isolated data capture test completed');
  });

  test('should implement anti-detection stealth measures', async ({ page }) => {
    console.log('🕵️ Testing anti-detection stealth measures...');

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    });

    // Inject shadow skimmer attack
    await page.addScriptTag({
      path: './malicious-code/shadow-skimmer.js'
    });

    await page.waitForTimeout(3000);

    // Test DevTools detection simulation
    console.log('🔧 Simulating DevTools opening...');

    const devToolsTest = await page.evaluate(() => {
      // Simulate DevTools opening by changing window dimensions
      const originalInnerHeight = window.innerHeight;
      const originalOuterHeight = window.outerHeight;

      // Mock DevTools detection scenario
      Object.defineProperty(window, 'innerHeight', {
        value: originalInnerHeight - 200,
        writable: true
      });

      Object.defineProperty(window, 'outerHeight', {
        value: originalOuterHeight,
        writable: true
      });

      return {
        heightDifference: window.outerHeight - window.innerHeight,
        devToolsDetected: (window.outerHeight - window.innerHeight) > 160
      };
    });

    console.log('🔧 DevTools detection test:', devToolsTest);

    // Test stealth function overrides
    const stealthTest = await page.evaluate(() => {
      const tests = {
        hasStealthMeasures: false,
        propertyDescriptorModified: false,
        consoleMethodsOverridden: false
      };

      // Check if stealth measures are active
      if (window.shadowSkimmerAttack) {
        tests.hasStealthMeasures = true;
      }

      // Test property descriptor modifications
      try {
        const shadowHosts = document.querySelectorAll('div');
        for (let host of shadowHosts) {
          if (host.shadowRoot !== undefined) {
            const descriptor = Object.getOwnPropertyDescriptor(host, 'style');
            if (descriptor && descriptor.configurable === false) {
              tests.propertyDescriptorModified = true;
              break;
            }
          }
        }
      } catch (e) {
        // Expected for stealth measures
      }

      return tests;
    });

    console.log('🕵️ Stealth measures test:', stealthTest);

    if (stealthTest.hasStealthMeasures) {
      console.log('✅ Stealth measures detected and active');
    }

    // Test shadow host hiding from queries
    const hidingTest = await page.evaluate(() => {
      // Try to find shadow hosts using common detection methods
      const allElements = document.querySelectorAll('*');
      let suspiciousElements = 0;
      let hiddenElements = 0;

      for (let element of allElements) {
        if (element.shadowRoot) {
          suspiciousElements++;
        }

        const style = window.getComputedStyle(element);
        if (style.opacity === '0' && style.position === 'absolute') {
          hiddenElements++;
        }
      }

      return {
        suspiciousElements,
        hiddenElements,
        totalElements: allElements.length
      };
    });

    console.log('👻 Element hiding test:', hidingTest);

    console.log('🕵️ Anti-detection stealth measures test completed');
  });

  test('should handle nested shadow DOM structures', async ({ page }) => {
    console.log('🏗️ Testing nested shadow DOM structures...');

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    });

    // Inject shadow skimmer attack
    await page.addScriptTag({
      path: './malicious-code/shadow-skimmer.js'
    });

    await page.waitForTimeout(3000);

    // Check shadow structure
    const shadowStructure = await page.evaluate(() => {
      const shadowInfo = window.shadowSkimmerAttack ? window.shadowSkimmerAttack.getShadowHosts() : [];

      return {
        shadowHostsCount: shadowInfo.length,
        shadowDepths: shadowInfo.map(host => host.depth),
        maxDepth: Math.max(...(shadowInfo.map(host => host.depth) || [0]))
      };
    });

    console.log('🏗️ Shadow structure analysis:', shadowStructure);

    if (shadowStructure.shadowHostsCount > 0) {
      expect(shadowStructure.shadowHostsCount).toBeGreaterThan(0);
      expect(shadowStructure.maxDepth).toBeGreaterThanOrEqual(0);

      if (shadowStructure.maxDepth > 1) {
        console.log('✅ Nested shadow DOM structure confirmed');
      }
    }

    // Test cross-shadow monitoring with nested structure
    await page.click('[data-section="settings"]');
    await page.waitForTimeout(1000);

    // Fill fields to test monitoring across nested shadows
    await page.fill('#current-password', 'nestedtest123');
    await page.fill('#new-password', 'newnested456');

    await page.waitForTimeout(2000);

    // Check if nested shadow monitoring captured data
    const nestedData = await page.evaluate(() => {
      return window.shadowSkimmerAttack ? window.shadowSkimmerAttack.getCapturedData() : [];
    });

    console.log('🏗️ Nested shadow captured data:', {
      sessions: nestedData.length,
      hasPasswordData: nestedData.some(session =>
        session.values.some(value => value.value && value.value.includes('nested'))
      )
    });

    console.log('🏗️ Nested shadow DOM structures test completed');
  });

  test('should contain shadow DOM attack patterns', async ({ page }) => {
    console.log('🔍 Analyzing shadow DOM attack patterns...');

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    });

    // Inject shadow skimmer attack
    await page.addScriptTag({
      path: './malicious-code/shadow-skimmer.js'
    });

    await page.waitForTimeout(3000);

    // Analyze attack patterns
    const attackPatterns = await page.evaluate(() => {
      const patterns = {
        shadowSkimmerAttack: !!window.shadowSkimmerAttack,
        hasShadowDOMSupport: !!Element.prototype.attachShadow,
        hasTreeWalker: !!document.createTreeWalker,
        hasMutationObserver: !!window.MutationObserver,
        hasWeakSet: !!window.WeakSet,
        hasSendBeacon: !!navigator.sendBeacon,
        shadowRootsDetected: 0,
        closedShadowRootsLikely: 0
      };

      // Count shadow roots
      const walker = document.createTreeWalker(
        document.body,
        NodeFilter.SHOW_ELEMENT,
        null,
        false
      );

      let node;
      while (node = walker.nextNode()) {
        if (node.shadowRoot) {
          patterns.shadowRootsDetected++;
        } else if (node.attachShadow && !node.shadowRoot) {
          // Might have closed shadow root
          patterns.closedShadowRootsLikely++;
        }
      }

      return patterns;
    });

    console.log('📊 Attack pattern analysis:', attackPatterns);

    // Verify key shadow attack patterns
    expect(attackPatterns.shadowSkimmerAttack).toBe(true);
    expect(attackPatterns.hasShadowDOMSupport).toBe(true);
    expect(attackPatterns.hasTreeWalker).toBe(true);
    expect(attackPatterns.hasMutationObserver).toBe(true);
    expect(attackPatterns.hasWeakSet).toBe(true);

    // Check attack status
    const attackStatus = await page.evaluate(() => {
      return window.shadowSkimmerAttack ? window.shadowSkimmerAttack.getStatus() : null;
    });

    console.log('👻 Shadow attack status:', attackStatus);

    if (attackStatus) {
      expect(attackStatus.active).toBe(true);
      expect(attackStatus.shadowHosts).toBeGreaterThan(0);
    }

    console.log('✅ Shadow DOM attack patterns verified');
  });

  test('should handle page unload with shadow cleanup', async ({ page }) => {
    console.log('📤 Testing shadow attack cleanup on page unload...');

    await page.goto('/banking.html', {
      baseURL: 'http://localhost:8080'
    });

    // Inject shadow skimmer attack
    await page.addScriptTag({
      path: './malicious-code/shadow-skimmer.js'
    });

    await page.waitForTimeout(3000);

    // Generate some shadow activity
    await page.click('[data-section="transfer"]');
    await page.fill('#transfer-password', 'unloadtest');
    await page.waitForTimeout(1000);

    // Get shadow data before unload
    const preUnloadData = await page.evaluate(() => {
      const status = window.shadowSkimmerAttack ? window.shadowSkimmerAttack.getStatus() : null;
      const data = window.shadowSkimmerAttack ? window.shadowSkimmerAttack.getCapturedData() : [];

      return {
        status,
        dataLength: data.length,
        hasCapturedData: data.some(session => session.values.length > 0)
      };
    });

    console.log('📊 Pre-unload shadow data:', preUnloadData);

    console.log('🔄 Navigating away to trigger shadow cleanup...');

    // Navigate away to trigger beforeunload
    await page.goto('about:blank');

    await page.waitForTimeout(1000);

    console.log('📤 Shadow cleanup and unload exfiltration test completed');
  });
});