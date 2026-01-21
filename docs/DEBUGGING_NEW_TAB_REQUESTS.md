# Debugging Requests in New Tabs/Windows

When links open in new tabs (`target="_blank"`), the Network tab in the original tab doesn't capture the new tab's network activity. This guide provides multiple approaches to debug these requests.

## The Problem

C2 links use `target="_blank"` to open in a new tab:
```html
<a href="/lab1/c2" class="c2-button" target="_blank">🕵️ View Stolen Data</a>
```

When you click this link:
- ✅ New tab opens with `/lab1/c2`
- ❌ Original tab's Network tab doesn't show the request
- ❌ You can't see if the cookie was sent

## Solution 1: Temporarily Remove `target="_blank"` (Easiest)

### Step-by-Step:

1. **Open DevTools** (F12) on the lab1 page
2. **Go to Elements tab**
3. **Find the C2 link:**
   - Right-click the "🕵️ View Stolen Data" link
   - Select "Inspect"
   - The `<a>` element will be highlighted

4. **Edit the HTML:**
   - Right-click the `<a>` element
   - Select "Edit as HTML"
   - Find `target="_blank"` and delete it (or change to `target="_self"`)
   - Press Enter to save

5. **Now click the link** - it opens in the same tab
6. **Check Network tab** - you'll see the request!

**Example:**
```html
<!-- Before -->
<a href="/lab1/c2" class="c2-button" target="_blank">🕵️ View Stolen Data</a>

<!-- After (for debugging) -->
<a href="/lab1/c2" class="c2-button">🕵️ View Stolen Data</a>
```

## Solution 2: Open DevTools in New Tab Before Clicking

### Step-by-Step:

1. **Right-click the C2 link**
2. **Select "Open in new tab"** (or Ctrl+Click / Cmd+Click)
3. **In the NEW tab**, press F12 to open DevTools
4. **Go to Network tab**
5. **Reload the page** (F5) to see the initial request
6. **Check Request Headers** for `Cookie:` header

**Note:** This works, but you miss the initial navigation request. The reload shows a subsequent request.

## Solution 3: Use Browser Console to Intercept Clicks (Most Reliable)

### Step-by-Step:

1. **Open DevTools** (F12) on the lab1 page
2. **Go to Console tab**
3. **Paste this script:**

```javascript
// Intercept C2 link clicks and open in same tab for debugging
(function() {
    const c2Button = document.querySelector('.c2-button');
    if (c2Button) {
        const originalHref = c2Button.href;
        const originalTarget = c2Button.target;
        
        // Remove target="_blank" temporarily
        c2Button.removeAttribute('target');
        
        // Add click listener to log request
        c2Button.addEventListener('click', function(e) {
            console.log('🔍 C2 link clicked:', {
                href: this.href,
                target: this.target,
                cookies: document.cookie,
                sessionStorage: sessionStorage.getItem('firebase_token') ? 'PRESENT' : 'MISSING'
            });
        });
        
        console.log('✅ C2 link debugging enabled - link will open in same tab');
        console.log('   Original target:', originalTarget);
        console.log('   Current cookies:', document.cookie);
    } else {
        console.warn('⚠️ C2 button not found');
    }
})();
```

4. **Press Enter** to run
5. **Click the C2 link** - it now opens in the same tab
6. **Check Network tab** for the request

## Solution 4: Use Server-Side Logging (Best for Production)

Since new tabs don't show in the original tab's Network tab, use server-side logs which capture ALL requests:

### Watch Traefik Logs:

```bash
# Watch all requests to /lab1/c2
docker logs -f e-skimming-labs-traefik 2>&1 | grep -E "\"RequestPath\":\"/lab1/c2\""

# Check if cookie is present
docker logs e-skimming-labs-traefik 2>&1 | grep -E "\"RequestPath\":\"/lab1/c2\"" | tail -1 | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    cookie = data.get('request_Cookie', 'NOT_FOUND')
    print('Cookie:', 'PRESENT ✅' if cookie != 'NOT_FOUND' and 'firebase_token' in cookie else 'MISSING ❌')
    if cookie != 'NOT_FOUND':
        print('Cookie preview:', cookie[:100] + '...' if len(cookie) > 100 else cookie)
    print('Sec-Fetch-Site:', data.get('request_Sec-Fetch-Site', 'NONE'))
    print('Referer:', data.get('request_Referer', 'NONE'))
except:
    print('Error parsing log')
"
```

### Watch home-index Logs:

```bash
# Watch ForwardAuth checks
docker logs -f e-skimming-labs-home-index 2>&1 | grep -E "(api/auth/check|Cookie|lab1/c2)"

# Or get last 50 lines
docker logs e-skimming-labs-home-index --tail=50 | grep -E "(api/auth/check|Cookie|DEBUG)"
```

**Look for:**
- `🔍 DEBUG: All headers received in /api/auth/check:`
- `🔍 Cookie header received: ...`
- `🔍 Token extracted from Cookie header`

## Solution 5: Use Chrome DevTools Protocol (CDP)

### Enable CDP:

1. **Start Chrome with remote debugging:**
   ```bash
   # macOS
   /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
   ```

2. **Connect to CDP and monitor all tabs:**
   ```javascript
   // In Node.js (requires chrome-remote-interface package)
   const CDP = require('chrome-remote-interface');
   
   CDP((client) => {
     const {Network, Runtime, Target} = client;
     
     // Monitor all network requests across all tabs
     Network.requestWillBeSent((params) => {
       if (params.request.url.includes('/lab1/c2')) {
         console.log('🔍 Request to /lab1/c2:', {
           url: params.request.url,
           headers: params.request.headers,
           cookie: params.request.headers.Cookie || 'NO_COOKIE',
           tabId: params.frameId
         });
       }
     });
     
     Network.enable();
     Runtime.enable();
   });
   ```

## Quick Debug Script

Save this as `debug-c2-click.js` and paste in Console:

```javascript
// Debug C2 link clicks
(function() {
    console.log('🔍 Setting up C2 link debugging...');
    
    // Find all C2 buttons
    const c2Buttons = document.querySelectorAll('.c2-button');
    
    if (c2Buttons.length === 0) {
        console.warn('⚠️ No C2 buttons found');
        return;
    }
    
    c2Buttons.forEach((button, index) => {
        console.log(`✅ Found C2 button ${index + 1}:`, {
            href: button.href,
            target: button.target,
            text: button.textContent.trim()
        });
        
        // Remove target="_blank" for debugging
        const originalTarget = button.target;
        button.removeAttribute('target');
        
        // Add click listener
        button.addEventListener('click', function(e) {
            console.log('🔍 C2 link clicked:', {
                href: this.href,
                cookies: document.cookie,
                sessionStorage: sessionStorage.getItem('firebase_token') ? 'PRESENT' : 'MISSING',
                timestamp: new Date().toISOString()
            });
            
            // Check cookie specifically
            const firebaseCookie = document.cookie.split('; ').find(row => row.startsWith('firebase_token='));
            if (firebaseCookie) {
                console.log('✅ firebase_token cookie found:', firebaseCookie.substring(0, 50) + '...');
            } else {
                console.error('❌ firebase_token cookie NOT found!');
            }
        });
        
        console.log(`   → Removed target="${originalTarget}" for debugging`);
    });
    
    console.log('✅ C2 link debugging enabled - links will open in same tab');
    console.log('   Open Network tab before clicking to see the request');
})();
```

## Recommended Workflow

1. **Use Solution 1** (remove `target="_blank"`) for quick debugging
2. **Use Solution 4** (server-side logs) for production debugging
3. **Use Solution 5** (CDP) for advanced debugging across multiple tabs

## Restore Original Behavior

After debugging, restore `target="_blank"`:

```javascript
// In Console
document.querySelectorAll('.c2-button').forEach(btn => {
    btn.setAttribute('target', '_blank');
});
```

Or simply reload the page - the change is temporary and only affects the current page load.
