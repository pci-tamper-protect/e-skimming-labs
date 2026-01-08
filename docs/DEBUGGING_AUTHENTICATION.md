# Authentication Debugging Guide

This guide provides step-by-step instructions for debugging authentication issues, particularly cookie/token passing problems.

## Prerequisites

- Chrome or Chromium-based browser
- Docker Compose running locally
- Access to terminal and browser DevTools

## Quick Debug Checklist

1. ✅ Cookie is set correctly (check Application → Cookies)
2. ✅ Cookie is sent in requests (check Network → Request Headers)
3. ✅ Traefik receives cookie (check Traefik logs)
4. ✅ ForwardAuth forwards cookie (check home-index logs)
5. ✅ Token is extracted correctly (check home-index logs)

## ⚠️ IMPORTANT: Debugging Links That Open in New Tabs

**The C2 link opens in a new tab (`target="_blank"`), so the Network tab in the original tab won't show the request.**

**Quick Fix:** See [DEBUGGING_NEW_TAB_REQUESTS.md](./DEBUGGING_NEW_TAB_REQUESTS.md) for detailed instructions, or:

1. **Right-click C2 link → Inspect**
2. **Right-click `<a>` element → Edit as HTML**
3. **Remove `target="_blank"`**
4. **Click link** - now opens in same tab
5. **Check Network tab** - you'll see the request!

**Or use server-side logs** (captures ALL requests regardless of tab):
```bash
docker logs -f e-skimming-labs-traefik 2>&1 | grep -E "(lab1/c2|Cookie)"
```

## Step-by-Step Debugging with Chrome DevTools

### Step 1: Clear All State

```bash
# Stop and restart services
docker-compose down
docker-compose up -d --build

# In browser:
# 1. Open DevTools (F12)
# 2. Application tab → Clear storage → Clear site data
# 3. Or manually:
#    - Application → Cookies → Delete all
#    - Application → Local Storage → Clear all
#    - Application → Session Storage → Clear all
```

### Step 2: Enable Request Logging

**In Chrome DevTools:**

1. Open DevTools (F12)
2. Go to **Network** tab
3. Check **Preserve log** (to keep logs across navigations)
4. Check **Disable cache** (to avoid cached responses)
5. Filter by **Fetch/XHR** or **All** to see all requests

### Step 3: Monitor Cookie Setting

**When logging in:**

1. Navigate to sign-in page: `http://127.0.0.1:8080/sign-in`
2. Open **Console** tab in DevTools
3. Add this monitor script:

```javascript
// Monitor cookie changes
(function() {
    const originalCookieSetter = Object.getOwnPropertyDescriptor(Document.prototype, 'cookie').set;
    Object.defineProperty(document, 'cookie', {
        set: function(value) {
            console.log('🍪 Cookie being set:', value);
            if (value.includes('firebase_token')) {
                console.log('✅ firebase_token cookie detected!');
                console.log('   Full cookie string:', value);
            }
            return originalCookieSetter.call(document, value);
        },
        get: function() {
            return originalCookieSetter.call(document);
        }
    });
})();
```

4. Fill in sign-in form and submit
5. Watch console for cookie setting messages
6. Verify cookie in **Application → Cookies → http://127.0.0.1:8080**

**Expected output:**
```
🍪 Cookie being set: firebase_token=eyJhbGci...; path=/; max-age=3600; SameSite=Lax
✅ firebase_token cookie detected!
```

### Step 4: Verify Cookie Attributes

**In DevTools → Application → Cookies:**

Check that `firebase_token` cookie has:
- ✅ **Name**: `firebase_token`
- ✅ **Value**: Starts with `eyJ` (JWT token)
- ✅ **Domain**: `127.0.0.1` (or your domain)
- ✅ **Path**: `/`
- ✅ **Expires**: ~1 hour from now
- ✅ **HttpOnly**: ❌ (should be false - we need JS access)
- ✅ **Secure**: ❌ (for HTTP) or ✅ (for HTTPS)
- ✅ **SameSite**: `Lax` (for HTTP) or `None` (for HTTPS)

### Step 5: Monitor Cookie Sending

**IMPORTANT: C2 Links Open in New Tab**

The C2 link uses `target="_blank"`, which opens in a new tab. The Network tab in the **original tab** won't show the new tab's requests.

**Option A: Debug in the New Tab (Recommended)**

1. **Before clicking C2 link:**
   - Right-click the C2 link → "Inspect"
   - In Elements tab, find the `<a>` tag
   - Right-click → "Edit as HTML"
   - Temporarily remove `target="_blank"` (or change to `target="_self"`)
   - Press Enter to save

2. **Open DevTools BEFORE clicking:**
   - Press F12 to open DevTools
   - Go to **Network** tab
   - Check **Preserve log** and **Disable cache**

3. **Click the C2 link** (now opens in same tab)
4. **Check Network tab** for the request to `/lab1/c2`
5. **Click on the request** → **Headers** tab → **Request Headers**
6. **Look for `Cookie:` header**

**Option B: Debug New Tab Requests**

1. **Click C2 link** (opens in new tab)
2. **In the NEW tab**, press F12 to open DevTools
3. **Go to Network tab** → Check **Preserve log**
4. **Reload the page** (F5) to see the initial request
5. **Check Request Headers** for `Cookie:` header

**Option C: Use Server-Side Logging (Best for Production Debugging)**

Since new tabs don't show in original tab's Network tab, use server-side logs:

```bash
# Watch Traefik logs in real-time (captures ALL requests regardless of tab)
docker logs -f e-skimming-labs-traefik 2>&1 | grep -E "(lab1/c2|Cookie)"

# Or watch home-index logs
docker logs -f e-skimming-labs-home-index 2>&1 | grep -E "(api/auth/check|Cookie|lab1/c2)"
```

**Expected in logs:**
```
Cookie: firebase_token=eyJhbGciOiJSUzI1NiIs...
```

**If missing:**
- Cookie is not being sent (SameSite issue or path mismatch)
- Check cookie attributes in Step 4
- Check browser console for cookie-related errors

### Step 6: Check Traefik Logs

**In terminal:**

```bash
# Watch Traefik logs in real-time
docker logs -f e-skimming-labs-traefik

# Filter for specific route
docker logs e-skimming-labs-traefik 2>&1 | grep -E "\"RequestPath\":\"/lab1/c2\"" | tail -5

# Check if cookie is present in Traefik access logs
docker logs e-skimming-labs-traefik 2>&1 | grep -E "\"RequestPath\":\"/lab1/c2\"" | tail -1 | python3 -c "
import sys, json
data = json.load(sys.stdin)
cookie = data.get('request_Cookie', 'NOT_FOUND')
print('Cookie in Traefik:', 'PRESENT' if cookie != 'NOT_FOUND' and 'firebase_token' in cookie else 'MISSING')
if cookie != 'NOT_FOUND':
    print('Cookie preview:', cookie[:100] + '...' if len(cookie) > 100 else cookie)
"
```

**Expected output:**
```
Cookie in Traefik: PRESENT
Cookie preview: firebase_token=eyJhbGci...
```

### Step 7: Check ForwardAuth Request

**In terminal:**

```bash
# Watch home-index logs for /api/auth/check calls
docker logs -f e-skimming-labs-home-index | grep -E "(api/auth/check|Cookie|DEBUG)"

# Or get last 50 lines
docker logs e-skimming-labs-home-index --tail=50 | grep -E "(api/auth/check|Cookie|DEBUG)"
```

**Look for:**
- `🔍 DEBUG: All headers received in /api/auth/check:`
- `🔍 Cookie header received: ...`
- `🔍 Token extracted from Cookie header`

**Expected log output:**
```
🔍 /api/auth/check called - Host: home-index:8080, X-Forwarded-Host: 127.0.0.1:8080, X-Forwarded-For: 172.18.0.1
🔍 DEBUG: All headers received in /api/auth/check:
🔍   Cookie: firebase_token=eyJhbGci... (length: 1234)
🔍 Token extracted from Cookie header (length: 1234)
✅ Token validated successfully (user: T7ZKY1lmD7RLA1hxQY8uuun5K5S2, email: user@example.com)
```

### Step 8: Test Token Extraction Manually

**Create a test script:**

```bash
# Save as test-token-extraction.sh
#!/bin/bash

# Test with Authorization header
echo "=== Test 1: Authorization Bearer Token ==="
curl -v http://127.0.0.1:8080/api/auth/user \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  2>&1 | grep -E "(< HTTP|authenticated)"

# Test with Cookie header
echo -e "\n=== Test 2: Cookie Header ==="
curl -v http://127.0.0.1:8080/api/auth/user \
  -H "Cookie: firebase_token=YOUR_TOKEN_HERE" \
  2>&1 | grep -E "(< HTTP|authenticated)"

# Test with query parameter
echo -e "\n=== Test 3: Query Parameter ==="
curl -v "http://127.0.0.1:8080/api/auth/user?token=YOUR_TOKEN_HERE" \
  2>&1 | grep -E "(< HTTP|authenticated)"
```

**Get your token from browser:**
```javascript
// In browser console
sessionStorage.getItem('firebase_token') || document.cookie.split('; ').find(row => row.startsWith('firebase_token='))?.split('=')[1]
```

### Step 9: Debug Cookie SameSite Issues

**Check Sec-Fetch-Site header:**

```bash
# In Traefik logs, check Sec-Fetch-Site header
docker logs e-skimming-labs-traefik 2>&1 | grep -E "\"RequestPath\":\"/lab1/c2\"" | tail -1 | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('Sec-Fetch-Site:', data.get('request_Sec-Fetch-Site', 'NONE'))
print('Referer:', data.get('request_Referer', 'NONE'))
print('Cookie present:', 'YES' if 'request_Cookie' in data and 'firebase_token' in data.get('request_Cookie', '') else 'NO')
"
```

**Expected for same-site:**
```
Sec-Fetch-Site: same-origin
Cookie present: YES
```

**Problem if cross-site:**
```
Sec-Fetch-Site: cross-site
Cookie present: NO  ← This is the problem!
```

**Solution:** Change cookie to `SameSite=None; Secure` (requires HTTPS) or ensure navigation is same-site.

### Step 10: Use Chrome DevTools Protocol (CDP)

**Enable CDP logging:**

1. Start Chrome with remote debugging:
   ```bash
   # macOS
   /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
   
   # Or use existing Chrome, connect via CDP
   ```

2. Use CDP to monitor network requests:
   ```javascript
   // In Node.js or browser console
   const CDP = require('chrome-remote-interface');
   
   CDP((client) => {
     const {Network, Runtime} = client;
     
     Network.requestWillBeSent((params) => {
       if (params.request.url.includes('/lab1/c2')) {
         console.log('Request to /lab1/c2:', {
           url: params.request.url,
           headers: params.request.headers,
           cookie: params.request.headers.Cookie || 'NO_COOKIE'
         });
       }
     });
     
     Network.enable();
     Runtime.enable();
   });
   ```

## Common Issues and Solutions

### Issue 1: Cookie Not Set

**Symptoms:**
- No cookie in Application → Cookies
- Console shows cookie setting but cookie doesn't appear

**Debug:**
```javascript
// Check if cookie is actually set
console.log('All cookies:', document.cookie);
console.log('firebase_token:', document.cookie.split('; ').find(c => c.startsWith('firebase_token=')));
```

**Solutions:**
- Check for JavaScript errors preventing cookie setting
- Verify domain/path are correct
- Check browser security settings

### Issue 2: Cookie Not Sent

**Symptoms:**
- Cookie exists in Application → Cookies
- Cookie NOT in Network → Request Headers

**Debug:**
```bash
# Check cookie attributes
# In DevTools → Application → Cookies → firebase_token
# Verify: Path=/, Domain matches, SameSite allows sending
```

**Solutions:**
- Change `SameSite=Lax` to `SameSite=None; Secure` (for HTTPS)
- Ensure navigation is same-site (check Sec-Fetch-Site header)
- Verify cookie path matches request path

### Issue 3: Cookie Sent But Not Received

**Symptoms:**
- Cookie in Network → Request Headers
- Cookie NOT in Traefik logs
- Cookie NOT in home-index logs

**Debug:**
```bash
# Check Traefik ForwardAuth configuration
curl http://127.0.0.1:8081/api/http/middlewares/lab1-auth-check@file | jq '.forwardAuth.authRequestHeaders'

# Should include "Cookie"
```

**Solutions:**
- Verify Traefik ForwardAuth `authRequestHeaders` includes `"Cookie"`
- Check Traefik is forwarding headers correctly
- Verify service is reachable from Traefik

### Issue 4: Token Extraction Fails

**Symptoms:**
- Cookie received in home-index logs
- Token extraction returns empty
- Token validation fails

**Debug:**
```bash
# Check token extraction logs
docker logs e-skimming-labs-home-index --tail=100 | grep -E "(Token|Cookie|extract)"
```

**Solutions:**
- Check for URL encoding issues
- Verify token format (should be JWT with 3 parts)
- Check for double-encoding

## Automated Testing

### Run Unit Tests

```bash
cd deploy/shared-components/home-index-service
go test ./auth -v
```

### Run Integration Tests

```bash
# Test token extraction with real HTTP requests
cd test
npm test -- auth-integration.spec.js
```

## Debugging Scripts

### Monitor All Auth-Related Requests

```bash
#!/bin/bash
# save as monitor-auth.sh

echo "Monitoring authentication requests..."
echo "Press Ctrl+C to stop"
echo ""

docker logs -f e-skimming-labs-home-index 2>&1 | grep -E "(auth|token|cookie|Cookie)" --color=always
```

### Check Cookie in All Services

```bash
#!/bin/bash
# save as check-cookies.sh

echo "=== Checking cookies in Traefik logs ==="
docker logs e-skimming-labs-traefik 2>&1 | grep -E "request_Cookie" | tail -5

echo -e "\n=== Checking cookies in home-index logs ==="
docker logs e-skimming-labs-home-index 2>&1 | grep -E "(Cookie|cookie)" | tail -5
```

## Next Steps

1. Run through all 10 steps above
2. Document findings at each step
3. Share logs and findings for further debugging
4. Consider adding more unit tests based on findings
