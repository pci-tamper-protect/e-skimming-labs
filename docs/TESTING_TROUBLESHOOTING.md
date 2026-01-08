# Testing & Troubleshooting Guide

Complete guide for testing and troubleshooting gcloud services and Traefik routing updates.

---

## 📚 Related Documentation

- **[Environment Testing Guide](./test/ENVIRONMENT_TESTING.md)** - Testing across local/staging/production
- **[Staging Guide](./STAGING.md)** - Complete staging environment setup
- **[Traefik Architecture](./TRAEFIK-ARCHITECTURE.md)** - Architecture and troubleshooting
- **[Traefik Router Setup](../deploy/TRAEFIK_ROUTER_SETUP.md)** - Cloud Run deployment details
- **[Traefik Testing](../deploy/traefik/TESTING.md)** - Local entrypoint.sh testing

---

## 🔄 GitHub Workflows

### Related Workflows

1. **[`.github/workflows/deploy_labs.yml`](../.github/workflows/deploy_labs.yml)**
   - Deploys all lab services and home components
   - Includes E2E tests with Traefik proxy for staging
   - Triggers: Push to `main`/`stg` branches, PRs
   - Manual trigger: `gh workflow run deploy_labs.yml -f environment=stg|prd`

2. **[`.github/workflows/test.yml`](../.github/workflows/test.yml)**
   - Runs E2E tests with parallel sharding
   - Supports local, staging, and production environments

### Viewing Workflow Runs

```bash
# List recent workflow runs
gh run list --workflow=deploy_labs.yml

# View specific run
gh run view <run-id>

# Watch a running workflow
gh run watch <run-id>
```

### Traefik Deployment

**Note:** Traefik is deployed manually using the build-and-push script, not via GitHub Actions workflow.

```bash
# Build and push Traefik image
cd deploy/traefik
./build-and-push.sh [stg|prd]

# Then deploy via gcloud (or use Terraform)
gcloud run deploy traefik-stg \
  --image=us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik:latest \
  --region=us-central1 \
  --project=labs-stg
```

---

## 🧪 Testing Traefik Locally

### Test entrypoint.sh Configuration

Before deploying to Cloud Run, test the Traefik configuration generation locally:

```bash
cd deploy/traefik
./test-entrypoint.sh [local|stg|prd]
```

**What it tests:**
- ✅ Token fetching logic (mocked)
- ✅ YAML generation
- ✅ Token escaping
- ✅ Middleware creation
- ✅ Router middleware assignment
- ✅ YAML syntax validation

**Output:**
- `test-output/dynamic/cloudrun-services.yml` - Generated config
- `test-output/test-output.log` - Full test output

See **[deploy/traefik/TESTING.md](../deploy/traefik/TESTING.md)** for details.

### Test Local Routing

```bash
# Start services with Traefik
docker-compose up -d

# Test routes
curl http://localhost:8080/
curl http://localhost:8080/lab1
curl http://localhost:8080/lab2
curl http://localhost:8080/lab3

# Check Traefik dashboard
open http://localhost:8081/dashboard/

# View registered services
curl http://localhost:8081/api/http/services | jq

# View routers
curl http://localhost:8081/api/http/routers | jq
```

---

## ☁️ Testing Cloud Run Services

### Verify Service Deployment

```bash
# Check service status
gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format="table(status.conditions[0].type,status.conditions[0].status,status.url)"

# Check service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg" \
  --limit=50 \
  --project=labs-stg \
  --format=json | jq
```

### Test Service Health

```bash
# Test health endpoint
SERVICE_URL=$(gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format='value(status.url)')

curl -f "${SERVICE_URL}/ping"
```

### Verify Service Account Permissions

```bash
# Run verification script
cd deploy/traefik
./verify_traefik_permissions.sh

# Or manually check
gcloud projects get-iam-policy labs-stg \
  --flatten="bindings[].members" \
  --filter="bindings.members:traefik-stg@labs-stg.iam.gserviceaccount.com"
```

---

## 🔍 Troubleshooting Traefik Routing

### Issue: 404 Not Found

**Symptoms:** Accessing a route returns 404

**Diagnosis:**
```bash
# Check if service is registered in Traefik
curl http://localhost:8081/api/http/services | jq '.[] | select(.name | contains("lab1"))'

# Check Traefik logs
docker-compose logs traefik | grep "lab1"

# Verify service is running
docker-compose ps
```

**Solutions:**
1. Verify service labels in `docker-compose.yml`
2. Check service is running: `docker-compose ps`
3. Restart Traefik: `docker-compose restart traefik`
4. For Cloud Run: Check environment variables are set correctly

### Issue: 502 Bad Gateway

**Symptoms:** Traefik returns 502 when accessing a service

**Diagnosis:**
```bash
# Check backend service logs
docker-compose logs lab1-vulnerable-site

# Test backend directly
docker exec lab1-techgear-store wget -O- http://localhost:80

# For Cloud Run: Check backend service status
gcloud run services describe lab-01-basic-magecart-stg \
  --region=us-central1 \
  --project=labs-stg
```

**Solutions:**
1. Verify backend service is running and healthy
2. Check service port matches Traefik configuration
3. For Cloud Run: Verify service account has `roles/run.invoker` permission
4. Check backend service logs for errors

### Issue: Traefik Can't Reach Backend Services (Cloud Run)

**Symptoms:** 502 errors, authentication failures

**Diagnosis:**
```bash
# Check Traefik service account permissions
gcloud projects get-iam-policy labs-stg \
  --flatten="bindings[].members" \
  --filter="bindings.members:traefik-stg@labs-stg.iam.gserviceaccount.com"

# Check backend service IAM policy
gcloud run services get-iam-policy home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg | grep traefik

# Verify backend is private (no allUsers)
gcloud run services get-iam-policy home-index-stg \
  --region=us-central1 \
  --project=labs-home-stg | grep allUsers
```

**Solutions:**
1. Ensure Traefik service account has `roles/run.invoker` on backend services
2. Verify backend services are private (no `allUsers` binding)
3. Check identity tokens are being generated correctly (see [Troubleshooting Authentication](#-troubleshooting-authentication))

### Issue: Static Assets Not Loading

**Symptoms:** HTML loads but CSS/JS fails

**Solutions:**
1. Check if `stripPrefix` middleware is correctly configured
2. Verify paths in HTML are relative (not absolute)
3. Update asset paths: `/css/style.css` → `css/style.css`
4. Check browser console for errors

### Issue: Infinite Redirects

**Symptoms:** Browser shows "too many redirects"

**Solutions:**
1. Check if multiple middlewares are adding redirects
2. Verify `X-Forwarded-Proto` header handling
3. Disable HTTP to HTTPS redirect in local development
4. Check Cloud Run ingress settings

---

## 🔐 Troubleshooting Authentication

### Issue: 403 Forbidden When Accessing Staging

**Symptoms:** Getting "Forbidden" error when accessing `https://labs.stg.pcioasis.com`

**Diagnosis:**
```bash
# Check your group membership
gcloud identity groups memberships check-transitive-membership \
  --group-email="2025-interns@pcioasis.com" \
  --member-email="your-email@pcioasis.com"

# Check Traefik IAM bindings
gcloud run services get-iam-policy traefik-stg \
  --region=us-central1 \
  --project=labs-stg
```

**Solutions:**

1. **Use gcloud proxy (Recommended):**
   ```bash
   gcloud run services proxy traefik-stg \
     --region=us-central1 \
     --project=labs-stg \
     --port=8081
   ```
   Then access `http://127.0.0.1:8081`

2. **Add your user directly:**
   ```bash
   cd deploy/terraform-home
   ./add-user-access.sh your-email@pcioasis.com
   ```

3. **Verify group membership:**
   - Ensure you're in `group:2025-interns@pcioasis.com` or `group:core-eng@pcioasis.com`
   - Contact Google Workspace admin to add you

See **[deploy/terraform-home/ACCESS_TROUBLESHOOTING.md](../deploy/terraform-home/ACCESS_TROUBLESHOOTING.md)** for details.

### Issue: Authentication Headers Not Being Sent

**Symptoms:** Backend services return 403, logs show "NO AUTH HEADER"

**Diagnosis:**
```bash
# Check Traefik logs for token generation
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg AND jsonPayload.message=~\"Token\"" \
  --limit=20 \
  --project=labs-stg

# Check if middleware is configured
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg AND jsonPayload.message=~\"Auth Middlewares\"" \
  --limit=10 \
  --project=labs-stg
```

**Solutions:**
1. Test entrypoint.sh locally: `cd deploy/traefik && ./test-entrypoint.sh stg`
2. Verify environment variables are set in Cloud Run service
3. Check that `entrypoint.sh` is generating auth middlewares correctly
4. Rebuild and redeploy Traefik image

### Issue: Traefik ForwardAuth Not Forwarding Cookie Header for C2 Routes

**Symptoms:** After signing in, accessing `/lab1/c2` or `/lab2/c2` redirects to sign-in page, even though the cookie is set and works for `/lab1` and `/lab2`.

**Root Cause:** The browser is not sending the cookie for C2 route requests. Traefik access logs show `NO_COOKIE` for `/lab1/c2` requests, while `/lab1` requests include the cookie. This is a browser/cookie issue, not a Traefik ForwardAuth configuration problem.

**Diagnosis Steps:**

1. **Verify Traefik ForwardAuth middleware configuration:**
   ```bash
   # Check middleware is configured correctly via Traefik API
   curl -s http://127.0.0.1:8081/api/http/middlewares/lab1-auth-check@file | jq -r '.forwardAuth'
   
   # Expected output should show:
   # {
   #   "address": "http://home-index:8080/api/auth/check",
   #   "authRequestHeaders": ["Authorization", "Cookie"],
   #   "authResponseHeaders": ["X-User-Id", "X-User-Email"],
   #   "trustForwardHeader": true
   # }
   ```

2. **Verify C2 routes are using correct middleware:**
   ```bash
   # Check router configuration
   curl -s http://127.0.0.1:8081/api/http/routers/lab1-c2@docker | jq -r '.middlewares[]'
   
   # Should show: lab1-auth-check@file
   ```

3. **Check what headers Traefik ForwardAuth is forwarding:**
   ```bash
   # Enable DEBUG logging in Traefik
   # Edit deploy/traefik/traefik.yml:
   # log:
   #   level: DEBUG
   
   docker-compose restart traefik
   
   # Check Traefik debug logs for middleware creation
   docker logs e-skimming-labs-traefik 2>&1 | grep -E "lab1-auth-check|ForwardAuth" | tail -10
   ```

4. **Check what headers are received by /api/auth/check:**
   ```bash
   # View home-index service logs with debug output
   docker logs e-skimming-labs-home-index --tail=50 | grep -E "(DEBUG|api/auth/check|Cookie|lab1/c2)" | tail -30
   
   # Look for:
   # - "🔍 DEBUG: All headers received in /api/auth/check:"
   # - Whether Cookie header is present
   ```

5. **Check Traefik access logs for cookie presence:**
   ```bash
   # Check if browser is sending cookie for /lab1/c2
   docker logs e-skimming-labs-traefik 2>&1 | grep -E "\"RequestPath\":\"/lab1/c2\"" | tail -1 | python3 -c "import sys, json; data=json.load(sys.stdin); print('Cookie:', 'PRESENT' if 'request_Cookie' in data and data['request_Cookie'] else 'MISSING'); print('Sec-Fetch-Site:', data.get('request_Sec-Fetch-Site', 'NONE'))"
   
   # Compare with /lab1 (should show Cookie: PRESENT)
   docker logs e-skimming-labs-traefik 2>&1 | grep -E "\"RequestPath\":\"/lab1\"" | grep -v "/lab1/" | tail -1 | python3 -c "import sys, json; data=json.load(sys.stdin); print('Cookie:', 'PRESENT' if 'request_Cookie' in data and data['request_Cookie'] else 'MISSING'); print('Sec-Fetch-Site:', data.get('request_Sec-Fetch-Site', 'NONE'))"
   ```

**Files Involved:**

1. **`deploy/traefik/dynamic/routes.yml`** - ForwardAuth middleware configuration:
   ```yaml
   lab1-auth-check:
     forwardAuth:
       address: "http://home-index:8080/api/auth/check"
       authResponseHeaders:
         - "X-User-Id"
         - "X-User-Email"
       authRequestHeaders:
         - "Authorization"
         - "Cookie"
       trustForwardHeader: true
   ```

2. **`docker-compose.yml`** - C2 route middleware assignment:
   ```yaml
   lab1-c2-server:
     labels:
       - "traefik.http.routers.lab1-c2.middlewares=lab1-auth-check@file,strip-lab1-c2-prefix@file"
   ```

3. **`deploy/shared-components/home-index-service/main.go`** - Auth check endpoint with debug logging:
   ```go
   // Lines 375-403: Auth check endpoint with comprehensive header logging
   mux.HandleFunc("/api/auth/check", func(w http.ResponseWriter, r *http.Request) {
       // DEBUG: Log ALL headers to see what Traefik ForwardAuth is actually forwarding
       log.Printf("🔍 DEBUG: All headers received in /api/auth/check:")
       for name, values := range r.Header {
           if strings.ToLower(name) == "cookie" {
               previewLen := 200
               if len(values[0]) < previewLen {
                   previewLen = len(values[0])
               }
               log.Printf("🔍   %s: %s (length: %d)", name, values[0][:previewLen], len(values[0]))
           } else {
               log.Printf("🔍   %s: %v", name, values)
           }
       }
       log.Printf("🔍 DEBUG: Request path: %s, method: %s, X-Forwarded-Uri: %s",
           r.URL.Path, r.Method, r.Header.Get("X-Forwarded-Uri"))
       // ... rest of auth check logic
   })
   ```

4. **`deploy/traefik/traefik.yml`** - Enable DEBUG logging:
   ```yaml
   log:
     level: DEBUG  # Enable DEBUG logging to see ForwardAuth middleware behavior
   ```

**Key Findings:**

- Traefik ForwardAuth middleware is configured correctly with `authRequestHeaders: ["Authorization", "Cookie"]`
- C2 routes are using the correct middleware (`lab1-auth-check@file`)
- The browser is NOT sending the cookie for `/lab1/c2` requests (Traefik access logs show `NO_COOKIE`)
- The browser IS sending the cookie for `/lab1` requests
- This is a browser/cookie issue, not a Traefik ForwardAuth configuration problem

**Potential Solutions:**

1. **Check cookie path/domain settings** - Ensure cookie is set with `path=/` and correct domain
2. **Check SameSite attribute** - `SameSite=Lax` may prevent cookie from being sent for certain navigation types
3. **Check browser console** - Look for cookie-related errors or warnings
4. **Check browser Network tab** - Verify cookie is actually being sent in request headers

**Reference Documentation:**
- [Traefik ForwardAuth Middleware](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [Traefik ForwardAuth Source Code](https://github.com/traefik/traefik/blob/master/pkg/middlewares/forwardauth/forwardauth.go)

### Why Path-Based Routing Can Cause Cross-Site Errors

**The Problem:**

When using path-based routing (e.g., `http://127.0.0.1:8080/lab1` and `http://127.0.0.1:8080/lab1/c2`), browsers may treat certain navigations as **cross-site** even though they're technically **same-origin**. This happens because:

1. **Browser's "Site" vs "Origin" Concept:**
   - **Origin** = `protocol://domain:port` (e.g., `http://127.0.0.1:8080`)
   - **Site** = `scheme://registrable domain` (e.g., `http://127.0.0.1`)
   - Browsers use the **site** concept for `SameSite` cookie policy and `Sec-Fetch-Site` header

2. **Navigation Context Matters:**
   - **Top-level navigation** (clicking a link): `SameSite=Lax` cookies are sent
   - **Cross-site navigation**: `SameSite=Lax` cookies are **NOT** sent
   - Browsers determine "cross-site" based on the **referrer** and **navigation context**

3. **Path-Based Routing Edge Cases:**
   - When navigating from `/lab1` to `/lab1/c2`, the browser may treat it as cross-site if:
     - The referrer policy causes the referrer to be missing or different
     - The navigation is triggered programmatically (e.g., `window.location.href`)
     - The link uses absolute URLs instead of relative URLs
     - The browser's security model flags the navigation as suspicious

**Evidence from Our Investigation:**

```bash
# Check Sec-Fetch-Site header for different routes
docker logs e-skimming-labs-traefik 2>&1 | grep -E "\"RequestPath\":\"/lab1/c2\"" | tail -1 | python3 -c "import sys, json; data=json.load(sys.stdin); print('Sec-Fetch-Site:', data.get('request_Sec-Fetch-Site', 'NONE'))"
# Output: cross-site

docker logs e-skimming-labs-traefik 2>&1 | grep -E "\"RequestPath\":\"/lab1\"" | grep -v "/lab1/" | tail -1 | python3 -c "import sys, json; data=json.load(sys.stdin); print('Sec-Fetch-Site:', data.get('request_Sec-Fetch-Site', 'NONE'))"
# Output: same-origin
```

**Why This Happens:**

1. **Referrer Policy:** If the referrer is missing or set to a different origin, browsers may treat the navigation as cross-site
2. **Link Construction:** If links use `window.location.protocol + '//' + hostname + '/c2'` instead of relative paths like `/lab1/c2`, browsers may flag it as cross-site
3. **Browser Security Model:** Modern browsers (especially Firefox) are more strict about what constitutes "same-site" navigation

**Solutions:**

1. **Use Relative URLs:** Always use relative paths (`/lab1/c2`) instead of constructing absolute URLs
2. **Set Cookie with `path=/`:** Ensure cookies are set with `path=/` to cover all routes
3. **Check Referrer Policy:** Ensure `Referrer-Policy` headers don't strip referrers
4. **Use `SameSite=None` for Cross-Site:** If you need cross-site cookies, use `SameSite=None` with `Secure` flag (requires HTTPS)

**Example of Problematic Code:**

```javascript
// ❌ BAD: Constructs absolute URL, may be treated as cross-site
const c2Url = window.location.protocol + '//' + window.location.hostname + '/lab1/c2';
window.location.href = c2Url;

// ✅ GOOD: Uses relative path, always same-site
window.location.href = '/lab1/c2';
```

**References:**
- [MDN: SameSite Cookies](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite)
- [MDN: Sec-Fetch-Site Header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Sec-Fetch-Site)
- [RFC 6265: HTTP State Management Mechanism](https://datatracker.ietf.org/doc/html/rfc6265)

### Cookie Storage and Request Flow

**Where the Cookie is Stored:**

The `firebase_token` cookie is stored in **two places** in the browser:

1. **Browser Cookie Storage** (HTTP Cookie):
   - **Location**: Browser's cookie storage (persistent across page reloads)
   - **Set via**: `document.cookie = 'firebase_token=' + encodeURIComponent(token) + '; path=/; max-age=3600; SameSite=None; Secure'`
   - **Attributes**:
     - `path=/` - Cookie is sent for all routes on the domain
     - `max-age=3600` - Cookie expires after 1 hour (3600 seconds)
     - `SameSite=None` - Allows cross-site requests (required for C2 routes)
     - `Secure` - Cookie only sent over HTTPS (required when `SameSite=None`)
   - **Storage Location**: Browser's cookie jar (managed by the browser)
   - **Access**: Automatically sent by browser in `Cookie` header for matching requests

2. **SessionStorage** (JavaScript Storage):
   - **Location**: Browser's `sessionStorage` (cleared when tab closes)
   - **Set via**: `sessionStorage.setItem('firebase_token', token)`
   - **Purpose**: Used for client-side JavaScript to access the token
   - **Access**: Only accessible via JavaScript (`sessionStorage.getItem('firebase_token')`)

**Code References:**

```2864:2866:deploy/shared-components/home-index-service/main.go
document.cookie = 'firebase_token=' + encodeURIComponent(token) + '; path=/; max-age=3600; SameSite=None; Secure';
console.log('🔍 Cookie set:', document.cookie.split(';').find(c => c.trim().startsWith('firebase_token=')));
sessionStorage.setItem('firebase_token', token);
```

**How the Cookie is Added Back into Requests:**

The browser **automatically** includes the cookie in HTTP requests based on:

1. **Cookie Matching Rules:**
   - **Domain**: Cookie domain matches request domain (or is a parent domain)
   - **Path**: Request path matches cookie path (`/` matches all paths)
   - **Secure**: If `Secure` flag is set, cookie only sent over HTTPS
   - **SameSite**: Cookie sent based on `SameSite` attribute:
     - `SameSite=None`: Cookie sent for all requests (requires `Secure`)
     - `SameSite=Lax`: Cookie sent for top-level navigations (default)
     - `SameSite=Strict`: Cookie only sent for same-site requests

2. **Request Flow:**

   ```
   Browser → HTTP Request → Cookie Header Added Automatically → Traefik → ForwardAuth → home-index-service
   ```

   **Step-by-Step:**

   a. **Browser Makes Request:**
      - User navigates to `/lab1/c2` or clicks a link
      - Browser checks cookie storage for matching cookies
      - If cookie matches (domain, path, Secure, SameSite), adds to `Cookie` header:
        ```
        Cookie: firebase_token=eyJhbGciOiJSUzI1NiIs...
        ```

   b. **Traefik Receives Request:**
      - Traefik receives request with `Cookie` header
      - Traefik's ForwardAuth middleware (`lab1-auth-check`) intercepts request
      - ForwardAuth forwards `Cookie` header to `/api/auth/check` endpoint
      - Reference: `deploy/traefik/dynamic/routes.yml`:
        ```yaml
        lab1-auth-check:
          forwardAuth:
            address: "http://home-index:8080/api/auth/check"
            authRequestHeaders:
              - "Authorization"
              - "Cookie"  # ← Cookie header is forwarded here
        ```

   c. **home-index-service Extracts Token:**
      - `/api/auth/check` endpoint receives request with `Cookie` header
      - Token extraction happens in multiple ways (fallback order):
      
      **Extraction Order** (`extractTokenFromRequest` function):
      
      1. **Authorization Header** (Bearer token):
         ```go
         authHeader := r.Header.Get("Authorization")
         // Format: "Bearer <token>"
         ```
      
      2. **Cookie Header** (parsed):
         ```go
         cookie, err := r.Cookie("firebase_token")
         // Go's http.Cookie() automatically URL-decodes the value
         ```
      
      3. **Cookie Header** (manual parsing):
         ```go
         cookieHeader := r.Header.Get("Cookie")
         // Parse manually: "firebase_token=...; other_cookie=..."
         ```
      
      4. **Query Parameter** (legacy support):
         ```go
         token := r.URL.Query().Get("token")
         ```

   **Code References:**

   ```2138:2174:deploy/shared-components/home-index-service/main.go
   func extractTokenFromRequest(r *http.Request) string {
   	// 1. Check Authorization header (Bearer token)
   	authHeader := r.Header.Get("Authorization")
   	if authHeader != "" {
   		parts := strings.SplitN(authHeader, " ", 2)
   		if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
   			return parts[1]
   		}
   	}

   	// 2. Check cookie (for client-side token passing)
   	cookie, err := r.Cookie("firebase_token")
   	if err == nil && cookie.Value != "" {
   		// Go's Cookie() method automatically URL-decodes cookie values
   		// The cookie is set with encodeURIComponent in JavaScript, so Go will decode it automatically
   		// However, if there's any issue with decoding, try manual decode
   		decodedValue, decodeErr := url.QueryUnescape(cookie.Value)
   		if decodeErr == nil && decodedValue != cookie.Value {
   			// Token was double-encoded, use decoded version
   			log.Printf("🔍 Cookie token decoded (was %d chars, now %d chars)", len(cookie.Value), len(decodedValue))
   			return decodedValue
   		}
   		log.Printf("🔍 Cookie token found (length: %d)", len(cookie.Value))
   		return cookie.Value
   	}
   	if err != nil {
   		log.Printf("🔍 Cookie not found: %v", err)
   	}

   	// 3. Check query parameter (for initial redirects)
   	token := r.URL.Query().Get("token")
   	if token != "" {
   		return token
   	}

   	return ""
   }
   ```

   ```470:513:deploy/shared-components/home-index-service/main.go
   // Check Cookie header directly (Traefik ForwardAuth forwards Cookie header as-is)
   if token == "" {
   	cookieHeader := r.Header.Get("Cookie")
   	if cookieHeader != "" {
   		previewLen := 100
   		if len(cookieHeader) < previewLen {
   			previewLen = len(cookieHeader)
   		}
   		log.Printf("🔍 Cookie header received: %s", cookieHeader[:previewLen])
   		// Parse the Cookie header manually to extract firebase_token
   		cookies := strings.Split(cookieHeader, ";")
   		for _, c := range cookies {
   			c = strings.TrimSpace(c)
   			if strings.HasPrefix(c, "firebase_token=") {
   				token = strings.TrimPrefix(c, "firebase_token=")
   				log.Printf("🔍 Token extracted from Cookie header (length: %d)", len(token))
   				break
   			}
   		}
   	}
   }
   // Check parsed cookie (fallback, but Cookie header should work)
   if token == "" {
   	cookie, err := r.Cookie("firebase_token")
   	if err == nil && cookie.Value != "" {
   		// Go's Cookie() automatically URL-decodes, but if cookie was set with encodeURIComponent,
   		// we might need to handle it. However, Go should decode it automatically.
   		// Check if it looks like a JWT (has 3 parts separated by dots)
   		token = cookie.Value
   		parts := strings.Split(token, ".")
   		if len(parts) != 3 {
   			// Token might be URL-encoded, try decoding
   			decodedValue, decodeErr := url.QueryUnescape(token)
   			if decodeErr == nil && decodedValue != token {
   				decodedParts := strings.Split(decodedValue, ".")
   				if len(decodedParts) == 3 {
   					log.Printf("🔍 Token was URL-encoded in cookie, decoded (was %d chars, now %d chars)", len(token), len(decodedValue))
   					token = decodedValue
   				}
   			}
   		}
   		log.Printf("🔍 Token found in parsed cookie (length: %d, parts: %d)", len(token), len(strings.Split(token, ".")))
   	} else {
   		log.Printf("🔍 Cookie not found or empty: %v", err)
   	}
   }
   ```

**Important Notes:**

1. **Cookie Encoding:**
   - JavaScript sets cookie with `encodeURIComponent(token)` to handle special characters
   - Go's `http.Cookie()` automatically URL-decodes cookie values
   - Manual `url.QueryUnescape()` is used as a fallback for double-encoded tokens

2. **Cookie Visibility:**
   - Cookies are **automatically** sent by the browser - no JavaScript needed
   - JavaScript can read cookies via `document.cookie`, but this is only for client-side use
   - Server-side code reads cookies from the `Cookie` HTTP header

3. **Cookie Scope:**
   - `path=/` ensures cookie is sent for all routes (`/lab1`, `/lab1/c2`, `/lab2`, etc.)
   - No `domain` attribute means cookie is scoped to the exact domain (e.g., `127.0.0.1:8080`)
   - `SameSite=None; Secure` allows cross-site requests (required for C2 routes)

4. **Debugging Cookie Issues:**
   - Check browser DevTools → Application → Cookies to see stored cookies
   - Check browser DevTools → Network → Request Headers to see if cookie is sent
   - Check Traefik access logs for `request_Cookie` field
   - Check `home-index-service` logs for cookie extraction debug messages

**References:**
- [MDN: HTTP Cookies](https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies)
- [MDN: Document.cookie](https://developer.mozilla.org/en-US/docs/Web/API/Document/cookie)
- [Go: http.Request.Cookie()](https://pkg.go.dev/net/http#Request.Cookie)
- [Traefik ForwardAuth: authRequestHeaders](https://doc.traefik.io/traefik/middlewares/http/forwardauth/#authrequestheaders)

### Issue: Cookie Not Sent When Navigating Back from C2 to Lab Home

**Symptoms:** After logging in on the C2 page (`/lab1/c2`), navigating back to the lab home page (`/lab1`) redirects to the sign-in page, even though the cookie was set correctly.

**Root Cause:** The cookie is set correctly, but when navigating back, the browser may not send the cookie due to:
1. **SameSite Cookie Restrictions:** `SameSite=Lax` cookies are NOT sent for cross-site navigations (even if same-origin)
2. **Cookie Not Converted to Authorization Header:** The client-side code reads the cookie and converts it to an `Authorization: Bearer` token, but this only happens for `/api/auth/user` calls, not for the initial page load
3. **Traefik ForwardAuth Dependency:** Traefik ForwardAuth middleware relies on the `Cookie` header being sent automatically by the browser

**How Authentication Works:**

1. **Server-Side (Traefik ForwardAuth):**
   - Browser automatically sends cookie in `Cookie` header
   - Traefik ForwardAuth forwards `Cookie` header to `/api/auth/check`
   - `/api/auth/check` extracts token from cookie and validates it
   - If valid, request proceeds; if invalid, redirects to sign-in

2. **Client-Side (JavaScript):**
   - JavaScript reads cookie from `document.cookie` or `sessionStorage`
   - Converts cookie value to `Authorization: Bearer <token>` header
   - Sends header in fetch requests to `/api/auth/user`
   - Used for UI updates (showing/hiding login/logout buttons)

**The Problem:**

When navigating from `/lab1/c2` back to `/lab1`:
- Browser may treat it as cross-site navigation (due to path-based routing)
- `SameSite=Lax` cookie is NOT sent automatically
- Traefik ForwardAuth doesn't receive cookie
- `/api/auth/check` fails → redirects to sign-in

**Solution:**

1. **Update Cookie SameSite Attribute:**
   - For HTTPS (production/staging): Use `SameSite=None; Secure`
   - For HTTP (local dev): Use `SameSite=Lax` (browsers may still send it for same-origin)
   - Code automatically detects protocol and sets appropriate attribute

2. **Ensure Cookie is Set Correctly:**
   - Cookie must be set with `path=/` to cover all routes
   - Cookie must be set on the same domain (no subdomain issues)
   - Both `sessionStorage` and cookie should be set (for redundancy)

3. **Verify Cookie is Sent:**
   - Check browser DevTools → Network → Request Headers → `Cookie` header
   - Check Traefik access logs for `request_Cookie` field
   - Check `home-index-service` logs for cookie extraction debug messages

**Code References:**

```2864:2867:deploy/shared-components/home-index-service/main.go
const isSecure = window.location.protocol === 'https:';
const sameSiteAttr = isSecure ? 'SameSite=None; Secure' : 'SameSite=Lax';
document.cookie = 'firebase_token=' + encodeURIComponent(token) + '; path=/; max-age=3600; ' + sameSiteAttr;
sessionStorage.setItem('firebase_token', token);
```

```1706:1714:deploy/shared-components/home-index-service/main.go
const token = sessionStorage.getItem('firebase_token') || document.cookie.split('; ').find(row => row.startsWith('firebase_token='))?.split('=')[1] || '';
const headers = {};
if (token) {
    headers['Authorization'] = 'Bearer ' + token;
}
fetch('/api/auth/user', {
    credentials: 'include',
    headers: headers
})
```

**Debugging Steps:**

1. **Check if cookie is set:**
   ```javascript
   // In browser console on C2 page after login
   console.log('Cookie:', document.cookie);
   console.log('sessionStorage:', sessionStorage.getItem('firebase_token'));
   ```

2. **Check if cookie is sent in request:**
   - Open DevTools → Network tab
   - Navigate from `/lab1/c2` to `/lab1`
   - Check the request to `/lab1` → Headers → Request Headers → `Cookie`

3. **Check Traefik logs:**
   ```bash
   docker logs e-skimming-labs-traefik --tail=50 | grep -E "\"RequestPath\":\"/lab1\"" | tail -1 | python3 -c "import sys, json; data=json.load(sys.stdin); print('Cookie:', 'PRESENT' if 'request_Cookie' in data and data['request_Cookie'] else 'MISSING')"
   ```

4. **Check home-index-service logs:**
   ```bash
   docker logs e-skimming-labs-home-index --tail=50 | grep -E "(api/auth/check|Cookie|lab1)"
   ```

**Note:** The client-side code converts cookies to Authorization Bearer tokens for `/api/auth/user` calls, but Traefik ForwardAuth relies on the browser automatically sending the cookie in the `Cookie` header. Both mechanisms are needed:
- **Cookie** (automatic) → For Traefik ForwardAuth and server-side auth checks
- **Authorization Bearer** (manual) → For client-side API calls and UI updates

---

## 🌐 Troubleshooting Domain & DNS

### Issue: Domain Not Pointing to Traefik

**Symptoms:** `labs.stg.pcioasis.com` doesn't resolve or points to wrong service

**Diagnosis:**
```bash
# Check domain mapping
gcloud run domain-mappings describe labs.stg.pcioasis.com \
  --region=us-central1 \
  --project=labs-stg

# Verify DNS records
dig labs.stg.pcioasis.com
```

**Solutions:**
1. **Update domain mapping:**
   ```bash
   # Delete old mapping
   gcloud run domain-mappings delete labs.stg.pcioasis.com \
     --region=us-central1 \
     --project=labs-stg

   # Create new mapping to Traefik
   gcloud run domain-mappings create labs.stg.pcioasis.com \
     --region=us-central1 \
     --project=labs-stg \
     --service=traefik-stg
   ```

2. **Check Cloudflare DNS settings** (if using Cloudflare)

### Issue: localhost vs 127.0.0.1 Proxy Access

**Symptoms:** `http://localhost:8081` gives 404, but `http://127.0.0.1:8081` works

**Solution:**
This is an IPv6/IPv4 resolution issue. Use `127.0.0.1` or use the helper script:

```bash
cd deploy/traefik
./proxy-traefik-stg.sh 8081
```

---

## 🧪 Testing After Updates

### After Updating Traefik Configuration

1. **Test locally:**
   ```bash
   cd deploy/traefik
   ./test-entrypoint.sh stg
   ```

2. **Rebuild and push image:**
   ```bash
   cd deploy/traefik
   ./build-and-push.sh stg
   ```

3. **Build and push image:**
   ```bash
   cd deploy/traefik
   ./build-and-push.sh stg
   ```

4. **Or deploy manually:**
   ```bash
   gcloud run deploy traefik-stg \
     --image=us-central1-docker.pkg.dev/labs-stg/e-skimming-labs/traefik:latest \
     --region=us-central1 \
     --project=labs-stg
   ```

5. **Restart proxy (if using):**
   ```bash
   pkill -f "gcloud run services proxy"
   gcloud run services proxy traefik-stg \
     --region=us-central1 \
     --project=labs-stg \
     --port=8081
   ```

6. **Verify deployment:**
   ```bash
   curl -f http://127.0.0.1:8081/ping
   ```

### After Updating Home Index Service

1. **Deploy service:**
   ```bash
   cd deploy/shared-components/home-index-service
   ./deploy-stg-simple.sh
   ```

2. **Restart proxy** (if using):
   ```bash
   pkill -f "gcloud run services proxy"
   gcloud run services proxy traefik-stg \
     --region=us-central1 \
     --project=labs-stg \
     --port=8081
   ```

3. **Test navigation:**
   - Home page loads
   - Links use relative URLs (when accessed via proxy)
   - Navigation between pages works

### After Updating Lab Services

1. **Deploy via GitHub Actions:**
   ```bash
   gh workflow run deploy_labs.yml -f environment=stg
   ```

2. **Or deploy specific lab:**
   ```bash
   # Check deploy_labs.yml for specific lab deployment commands
   ```

3. **Test lab functionality:
   - Lab loads correctly
   - C2 server accessible
   - Navigation works

---

## 📊 Monitoring & Logs

### View Traefik Logs

```bash
# Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg" \
  --limit=50 \
  --project=labs-stg \
  --format=json | jq

# Filter for specific routes
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg AND jsonPayload.RequestPath=~\"/lab1\"" \
  --limit=20 \
  --project=labs-stg

# Filter for auth issues
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=traefik-stg AND (jsonPayload.message=~\"Token\" OR jsonPayload.message=~\"Auth\")" \
  --limit=20 \
  --project=labs-stg
```

### View Backend Service Logs

```bash
# Home index service
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=home-index-stg" \
  --limit=50 \
  --project=labs-home-stg

# Lab service
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=lab-01-basic-magecart-stg" \
  --limit=50 \
  --project=labs-stg
```

### Check Service Metrics

```bash
# Open Cloud Console
open "https://console.cloud.google.com/run/detail/us-central1/traefik-stg/metrics?project=labs-stg"
```

---

## 🧪 E2E Testing

### Running E2E Tests

```bash
# Local environment
cd test
TEST_ENV=local npm test

# Staging environment (uses proxy automatically in CI)
cd test
TEST_ENV=stg npm test

# Production environment
cd test
TEST_ENV=prd npm test
```

### Staging E2E Tests with Proxy

The GitHub Actions workflow automatically:
1. Starts `gcloud run services proxy` for Traefik
2. Sets `PROXY_URL` and `USE_PROXY` environment variables
3. Runs tests against the proxy
4. Cleans up proxy after tests

See **[docs/STAGING_E2E_PROXY.md](./STAGING_E2E_PROXY.md)** for details.

### Manual E2E Testing with Proxy

```bash
# Start proxy in background
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8081 &

# Run tests
cd test
export PROXY_URL="http://127.0.0.1:8081"
export USE_PROXY="true"
export TEST_ENV="stg"
npm test

# Stop proxy
pkill -f "gcloud run services proxy"
```

---

## 🔧 Quick Reference Commands

### Service Status

```bash
# List all Cloud Run services
gcloud run services list --project=labs-stg --region=us-central1

# Describe specific service
gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg

# Get service URL
gcloud run services describe traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --format='value(status.url)'
```

### IAM Permissions

```bash
# Check service IAM policy
gcloud run services get-iam-policy traefik-stg \
  --region=us-central1 \
  --project=labs-stg

# Check project-level IAM
gcloud projects get-iam-policy labs-stg \
  --flatten="bindings[].members" \
  --filter="bindings.members:traefik-stg@labs-stg.iam.gserviceaccount.com"
```

### Proxy Commands

```bash
# Start proxy
gcloud run services proxy traefik-stg \
  --region=us-central1 \
  --project=labs-stg \
  --port=8081

# Stop proxy
pkill -f "gcloud run services proxy"

# Check if proxy is running
ps aux | grep "gcloud run services proxy"
```

### Testing Routes

```bash
# Test health endpoint
curl http://127.0.0.1:8081/ping

# Test home page
curl http://127.0.0.1:8081/

# Test lab routes
curl http://127.0.0.1:8081/lab1
curl http://127.0.0.1:8081/lab2
curl http://127.0.0.1:8081/lab3
```

---

## 📝 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| 404 on routes | Check service labels, restart Traefik |
| 502 Bad Gateway | Verify backend service is running, check IAM permissions |
| 403 Forbidden | Use proxy or add user to IAM groups |
| Auth headers missing | Test entrypoint.sh, rebuild image |
| Domain not resolving | Check domain mapping, DNS records |
| localhost vs 127.0.0.1 | Use 127.0.0.1 or helper script |
| Changes not reflected | Restart proxy after deployment |

---

## 🔗 Additional Resources

- **[Traefik Official Docs](https://doc.traefik.io/traefik/)**
- **[Cloud Run Troubleshooting](https://cloud.google.com/run/docs/troubleshooting)**
- **[gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference)**

---

## 🆘 Getting Help

1. Check logs first (see [Monitoring & Logs](#-monitoring--logs))
2. Review related documentation (see [Related Documentation](#-related-documentation))
3. Check GitHub workflow runs for deployment issues
4. Open a GitHub issue with:
   - Error messages
   - Relevant logs
   - Steps to reproduce
   - Environment (local/staging/production)
