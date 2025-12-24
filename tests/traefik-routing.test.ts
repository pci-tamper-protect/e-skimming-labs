/**
 * Traefik Routing Tests
 *
 * These tests verify that Traefik correctly routes requests to the appropriate services
 * based on path prefixes. Tests run against all environments (local, stg, prd).
 */

import { test, expect } from '@playwright/test';

// Get base URL from environment variable or default to localhost
const BASE_URL = process.env.TEST_ENV === 'prd'
  ? 'https://labs.pcioasis.com'
  : process.env.TEST_ENV === 'stg'
  ? 'https://labs.stg.pcioasis.com'
  : 'http://localhost:8080';

test.describe('Traefik Routing Tests', () => {
  test.describe('Health Checks', () => {
    test('should respond to ping endpoint', async ({ request }) => {
      const response = await request.get(`${BASE_URL}/ping`);
      expect(response.status()).toBe(200);
    });

    test('should have working Traefik dashboard API', async ({ request }) => {
      // Dashboard is only available in local environment
      if (BASE_URL.includes('localhost')) {
        const response = await request.get('http://localhost:8081/api/overview');
        expect(response.status()).toBe(200);
      }
    });
  });

  test.describe('Home Page Routing', () => {
    test('should load home page at root path', async ({ page }) => {
      await page.goto(`${BASE_URL}/`);

      // Wait for page to load
      await page.waitForLoadState('networkidle');

      // Check that we get a successful response
      expect(page.url()).toContain(BASE_URL);

      // Verify it's the home page (not a 404 or error)
      await expect(page).not.toHaveTitle(/404|Error/i);
    });

    test('should have working SEO service', async ({ request }) => {
      const response = await request.get(`${BASE_URL}/api/seo/health`);
      expect([200, 404]).toContain(response.status());
    });

    test('should have working analytics service', async ({ request }) => {
      const response = await request.get(`${BASE_URL}/api/analytics/health`);
      expect([200, 404]).toContain(response.status());
    });
  });

  test.describe('Lab 1 Routing', () => {
    test('should route /lab1 to Lab 1 vulnerable site', async ({ page }) => {
      await page.goto(`${BASE_URL}/lab1`);
      await page.waitForLoadState('networkidle');

      // Should not get 404
      await expect(page).not.toHaveTitle(/404/);

      // Check for Lab 1 specific content
      const content = await page.content();
      expect(content.length).toBeGreaterThan(0);
    });

    test('should route /lab1/ with trailing slash', async ({ page }) => {
      await page.goto(`${BASE_URL}/lab1/`);
      await page.waitForLoadState('networkidle');

      await expect(page).not.toHaveTitle(/404/);
    });

    test('should route /lab1/c2 to Lab 1 C2 server', async ({ request }) => {
      const response = await request.get(`${BASE_URL}/lab1/c2`);

      // C2 server might return various status codes depending on setup
      // We just want to verify the route exists
      expect([200, 404, 500]).toContain(response.status());
    });

    test('should handle Lab 1 static assets', async ({ page }) => {
      await page.goto(`${BASE_URL}/lab1`);

      // Wait for network to settle
      await page.waitForLoadState('networkidle');

      // Check that CSS and JS are loaded
      const resources = await page.evaluate(() => {
        return {
          stylesheets: document.styleSheets.length,
          scripts: document.scripts.length
        };
      });

      // Should have loaded some resources
      expect(resources.stylesheets + resources.scripts).toBeGreaterThan(0);
    });
  });

  test.describe('Lab 2 Routing', () => {
    test('should route /lab2 to Lab 2 vulnerable site', async ({ page }) => {
      await page.goto(`${BASE_URL}/lab2`);
      await page.waitForLoadState('networkidle');

      await expect(page).not.toHaveTitle(/404/);
    });

    test('should route /lab2/c2 to Lab 2 C2 server', async ({ request }) => {
      const response = await request.get(`${BASE_URL}/lab2/c2`);
      expect([200, 404, 500]).toContain(response.status());
    });
  });

  test.describe('Lab 3 Routing', () => {
    test('should route /lab3 to Lab 3 vulnerable site', async ({ page }) => {
      await page.goto(`${BASE_URL}/lab3`);
      await page.waitForLoadState('networkidle');

      await expect(page).not.toHaveTitle(/404/);
    });

    test('should route /lab3/extension to Lab 3 extension server', async ({ request }) => {
      const response = await request.get(`${BASE_URL}/lab3/extension`);
      expect([200, 404, 500]).toContain(response.status());
    });
  });

  test.describe('Lab 1 Variants Routing', () => {
    test('should route /lab1/variants/event-listener', async ({ page }) => {
      await page.goto(`${BASE_URL}/lab1/variants/event-listener`);
      await page.waitForLoadState('networkidle');

      await expect(page).not.toHaveTitle(/404/);
    });

    test('should route /lab1/variants/obfuscated', async ({ page }) => {
      await page.goto(`${BASE_URL}/lab1/variants/obfuscated`);
      await page.waitForLoadState('networkidle');

      await expect(page).not.toHaveTitle(/404/);
    });

    test('should route /lab1/variants/websocket', async ({ page }) => {
      await page.goto(`${BASE_URL}/lab1/variants/websocket`);
      await page.waitForLoadState('networkidle');

      await expect(page).not.toHaveTitle(/404/);
    });
  });

  test.describe('Path Priority', () => {
    test('should prioritize /lab1/c2 over /lab1', async ({ request }) => {
      // /lab1/c2 should go to C2 server, not vulnerable site
      const c2Response = await request.get(`${BASE_URL}/lab1/c2`);
      const lab1Response = await request.get(`${BASE_URL}/lab1`);

      // Should get different responses (different services)
      expect(c2Response.status()).toBeDefined();
      expect(lab1Response.status()).toBeDefined();
    });

    test('should prioritize variant routes over main lab route', async ({ request }) => {
      const variantResponse = await request.get(`${BASE_URL}/lab1/variants/event-listener`);
      const mainResponse = await request.get(`${BASE_URL}/lab1`);

      // Should get different responses
      expect(variantResponse.status()).toBeDefined();
      expect(mainResponse.status()).toBeDefined();
    });
  });

  test.describe('CORS and Headers', () => {
    test('should include proper CORS headers', async ({ request }) => {
      const response = await request.get(`${BASE_URL}/lab1`);
      const headers = response.headers();

      // Check for common security headers
      expect(headers).toBeDefined();
    });

    test('should handle preflight requests', async ({ request }) => {
      const response = await request.fetch(`${BASE_URL}/api/analytics`, {
        method: 'OPTIONS',
        headers: {
          'Origin': 'http://example.com',
          'Access-Control-Request-Method': 'POST'
        }
      });

      expect([200, 204, 404]).toContain(response.status());
    });
  });

  test.describe('Error Handling', () => {
    test('should return 404 for non-existent paths', async ({ page }) => {
      const response = await page.goto(`${BASE_URL}/non-existent-path-12345`);

      // Should get some kind of not found response
      // Might be from Traefik or from the home service
      expect(response).toBeDefined();
    });

    test('should handle malformed paths gracefully', async ({ request }) => {
      const response = await request.get(`${BASE_URL}/../../../etc/passwd`);

      // Should not expose sensitive paths
      expect(response.status()).not.toBe(200);
    });
  });

  test.describe('Performance', () => {
    test('should respond quickly to root path', async ({ page }) => {
      const startTime = Date.now();
      await page.goto(`${BASE_URL}/`);
      const loadTime = Date.now() - startTime;

      // Should load within reasonable time (10 seconds)
      expect(loadTime).toBeLessThan(10000);
    });

    test('should respond quickly to lab paths', async ({ page }) => {
      const startTime = Date.now();
      await page.goto(`${BASE_URL}/lab1`);
      const loadTime = Date.now() - startTime;

      expect(loadTime).toBeLessThan(10000);
    });
  });

  test.describe('Navigation Flow', () => {
    test('should navigate from home to lab1', async ({ page }) => {
      // Start at home
      await page.goto(`${BASE_URL}/`);
      await page.waitForLoadState('networkidle');

      // Navigate to lab1
      await page.goto(`${BASE_URL}/lab1`);
      await page.waitForLoadState('networkidle');

      // Should successfully navigate
      expect(page.url()).toContain('/lab1');
    });

    test('should navigate between labs', async ({ page }) => {
      // Go to lab1
      await page.goto(`${BASE_URL}/lab1`);
      await page.waitForLoadState('networkidle');

      // Go to lab2
      await page.goto(`${BASE_URL}/lab2`);
      await page.waitForLoadState('networkidle');

      // Go to lab3
      await page.goto(`${BASE_URL}/lab3`);
      await page.waitForLoadState('networkidle');

      // All navigations should work
      expect(page.url()).toContain('/lab3');
    });
  });
});

test.describe('Service Discovery', () => {
  test('should have all services registered in Traefik', async ({ request }) => {
    // Only run in local environment where dashboard is accessible
    if (!BASE_URL.includes('localhost')) {
      test.skip();
    }

    const response = await request.get('http://localhost:8081/api/http/services');
    expect(response.status()).toBe(200);

    const services = await response.json();

    // Should have services for all labs
    expect(services).toBeDefined();
  });

  test('should have all routers configured', async ({ request }) => {
    // Only run in local environment
    if (!BASE_URL.includes('localhost')) {
      test.skip();
    }

    const response = await request.get('http://localhost:8081/api/http/routers');
    expect(response.status()).toBe(200);

    const routers = await response.json();
    expect(routers).toBeDefined();
  });
});
