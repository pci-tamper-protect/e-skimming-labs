# Lab Authentication Setup

This guide explains how to add Firebase authentication to individual lab pages.

## Overview

Labs are protected by loading the authentication script from the home-index service. The auth system:
- Automatically detects if `FIREBASE_API_KEY` is available
- Only enables authentication when credentials are present
- Works seamlessly with the main app's SSO system

## Quick Setup

Add these scripts to your lab HTML pages (before the closing `</body>` tag):

```html
<!-- Auto-detect auth configuration from home-index service -->
<script>
(function() {
    // Replace with your home-index service URL
    const HOME_INDEX_URL = 'http://localhost:3000';  // or 'https://labs.pcioasis.com'
    
    // Check if auth is enabled
    fetch(HOME_INDEX_URL + '/api/auth/config')
        .then(res => res.json())
        .then(config => {
            if (config.authEnabled) {
                // Load auth script
                const script = document.createElement('script');
                script.src = HOME_INDEX_URL + '/static/js/auth.js';
                script.onload = function() {
                    // Initialize auth
                    if (typeof initLabsAuth === 'function') {
                        initLabsAuth({
                            authRequired: config.authRequired,  // Set to true to require auth
                            mainAppURL: config.mainAppURL,
                            firebaseProjectID: config.firebaseProjectID,
                            authServiceURL: HOME_INDEX_URL
                        });
                    }
                };
                document.head.appendChild(script);
            } else {
                console.log('🔓 Running without authentication');
            }
        })
        .catch(err => {
            console.log('🔓 Auth not available, running without authentication:', err);
        });
})();
</script>
```

## Manual Configuration

If you prefer to configure auth manually:

```html
<script src="http://localhost:3000/static/js/auth.js"></script>
<script>
    if (typeof initLabsAuth === 'function') {
        initLabsAuth({
            authRequired: true,  // Require authentication
            mainAppURL: 'https://www.pcioasis.com',
            firebaseProjectID: 'ui-firebase-pcioasis-prd',
            authServiceURL: 'http://localhost:3000'  // home-index service URL
        });
    }
</script>
```

## Environment Detection

The home-index service automatically detects if authentication should be enabled:

- **With `FIREBASE_API_KEY`**: Authentication is enabled, labs will be protected
- **Without `FIREBASE_API_KEY`**: Authentication is disabled, labs run without auth

## Configuration Options

### `authRequired` (boolean)
- `true`: Users must be authenticated to access the lab
- `false`: Authentication is optional (default)

### `mainAppURL` (string)
- URL of the main e-skimming-app (for sign-in redirects)
- Example: `https://www.pcioasis.com`

### `firebaseProjectID` (string)
- Firebase project ID
- Example: `ui-firebase-pcioasis-prd`

### `authServiceURL` (string)
- URL of the home-index service (for token validation)
- Example: `http://localhost:3000` or `https://labs.pcioasis.com`

## How It Works

1. **Token Storage**: Firebase tokens are stored in `sessionStorage` as `firebase_token`
2. **Token Validation**: Tokens are validated via `/api/auth/validate` endpoint
3. **SSO Support**: Labs can receive tokens from the main app via `postMessage`
4. **Redirect Flow**: Unauthenticated users are redirected to the main app's sign-in page

## Example: Lab 1 (Basic Magecart)

Add to `labs/01-basic-magecart/vulnerable-site/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <!-- ... existing head content ... -->
  </head>
  <body>
    <!-- ... existing body content ... -->
    
    <!-- Auth Integration -->
    <script>
    (function() {
        const HOME_INDEX_URL = window.location.hostname === 'localhost' 
            ? 'http://localhost:3000' 
            : 'https://labs.pcioasis.com';
        
        fetch(HOME_INDEX_URL + '/api/auth/config')
            .then(res => res.json())
            .then(config => {
                if (config.authEnabled) {
                    const script = document.createElement('script');
                    script.src = HOME_INDEX_URL + '/static/js/auth.js';
                    script.onload = function() {
                        if (typeof initLabsAuth === 'function') {
                            initLabsAuth({
                                authRequired: true,
                                mainAppURL: config.mainAppURL,
                                firebaseProjectID: config.firebaseProjectID,
                                authServiceURL: HOME_INDEX_URL
                            });
                        }
                    };
                    document.head.appendChild(script);
                }
            })
            .catch(err => console.log('🔓 Running without authentication'));
    })();
    </script>
  </body>
</html>
```

## Testing

1. **Without Auth**: Remove or don't set `FIREBASE_API_KEY` - labs should work without authentication
2. **With Auth**: Set `FIREBASE_API_KEY` - labs should require authentication
3. **SSO**: Sign in at `www.pcioasis.com`, then navigate to a lab - should be automatically authenticated

## Troubleshooting

- **"Auth not available"**: Check that home-index service is running and `FIREBASE_API_KEY` is set
- **"Token validation failed"**: Check that the auth service URL is correct and CORS is enabled
- **"Redirect loop"**: Ensure `mainAppURL` points to the correct main app domain

