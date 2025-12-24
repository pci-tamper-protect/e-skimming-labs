# Authentication & SSO Analysis for E-Skimming Labs

## Executive Summary

**Is this a good idea?** ✅ **Yes, with caveats**

Adding optional SSO authentication to e-skimming-labs is feasible and provides value, but requires careful implementation to maintain the educational nature of the platform while adding access control when needed.

## Current Architecture

### e-skimming-app (www.pcioasis.com)
- **Stack**: React + Vite
- **Auth**: Firebase Authentication (Email/Password + Google OAuth)
- **Token Storage**: localStorage (`accessToken` - Firebase JWT)
- **State Management**: Zustand (`authStore`)
- **Protected Routes**: `ProtectedRoute` component
- **Token Format**: Firebase ID Token (JWT)

### e-skimming-labs (labs.pcioasis.com)
- **Stack**: Go HTTP server (`home-index-service`) + Static HTML/JS/CSS
- **Auth**: None currently
- **Services**: Multiple Cloud Run services (home-index, labs, C2 servers)
- **Deployment**: Cloud Run with environment-based configuration

## SSO Implementation Approach

### Option 1: Client-Side Token Sharing (Recommended)
**Complexity: Medium** ⚙️

**How it works:**
1. User signs in at `www.pcioasis.com` → Firebase token stored in localStorage
2. User navigates to `labs.pcioasis.com`
3. Client-side JavaScript checks for token in localStorage
4. If token exists, sends it to Go server for validation
5. Go server validates token with Firebase Admin SDK
6. Server sets session cookie or continues with token-based auth

**Pros:**
- ✅ Simple implementation
- ✅ No changes needed to e-skimming-app
- ✅ Works across subdomains (same-origin policy allows localStorage sharing)
- ✅ Optional per environment via feature flag

**Cons:**
- ⚠️ localStorage is domain-specific (www.pcioasis.com vs labs.pcioasis.com)
- ⚠️ Requires token passing mechanism (URL param, postMessage, or cookie)

**Implementation Complexity:**
- **e-skimming-app**: Minimal (0-1 files) - Optional helper to pass token
- **e-skimming-labs**: Medium (3-5 files) - Auth middleware, token validation, protected routes

### Option 2: Cookie-Based SSO (More Robust)
**Complexity: Medium-High** ⚙️⚙️

**How it works:**
1. User signs in at `www.pcioasis.com`
2. e-skimming-app sets a secure, HttpOnly cookie with Firebase token
3. Cookie is set for `.pcioasis.com` domain (shared across subdomains)
4. e-skimming-labs reads cookie and validates token
5. Optional: Refresh token mechanism

**Pros:**
- ✅ Automatic token sharing across subdomains
- ✅ More secure (HttpOnly cookies)
- ✅ No client-side token passing needed

**Cons:**
- ⚠️ Requires changes to both repos
- ⚠️ Cookie security considerations (SameSite, Secure flags)
- ⚠️ CORS configuration needed

**Implementation Complexity:**
- **e-skimming-app**: Medium (2-3 files) - Cookie setting logic, token refresh
- **e-skimming-labs**: Medium (3-5 files) - Cookie reading, token validation

### Option 3: Firebase Auth State Persistence (Simplest)
**Complexity: Low-Medium** ⚙️

**How it works:**
1. Both apps use the same Firebase project
2. e-skimming-labs includes Firebase Auth SDK in client-side JavaScript
3. Client checks `auth.currentUser` on page load
4. If authenticated, sends token to Go server for validation
5. Server validates and allows access

**Pros:**
- ✅ Minimal server-side changes
- ✅ Leverages existing Firebase Auth
- ✅ Automatic token refresh

**Cons:**
- ⚠️ Requires Firebase SDK in e-skimming-labs (adds ~200KB)
- ⚠️ Client-side only (less secure for sensitive operations)
- ⚠️ Still need server-side validation for protected routes

**Implementation Complexity:**
- **e-skimming-app**: None (no changes)
- **e-skimming-labs**: Low-Medium (2-4 files) - Firebase SDK integration, client auth check, server validation

## Recommended Approach: Hybrid (Option 1 + Option 3)

Combine client-side Firebase Auth check with server-side token validation:

1. **Client-side** (e-skimming-labs HTML/JS):
   - Include Firebase Auth SDK (lightweight, ~50KB gzipped)
   - Check `auth.currentUser` on page load
   - If authenticated, extract token and send to server

2. **Server-side** (Go middleware):
   - Validate Firebase token using Firebase Admin SDK
   - Optional: Cache validation results
   - Set user context for protected routes

3. **Environment-based toggle**:
   - Environment variable: `ENABLE_AUTH=true/false`
   - Feature flag in Go server
   - Conditional rendering in HTML templates

## Implementation Complexity Breakdown

### e-skimming-app Changes
**Files to modify: 0-2**

1. **Optional**: Token sharing helper (if using Option 1)
   - `src/shared/utils/ssoHelper.js` (new file, ~50 lines)
   - Function to pass token to labs domain via postMessage or URL

**Estimated effort: 1-2 hours**

### e-skimming-labs Changes
**Files to create/modify: 5-8**

1. **Go Server** (`deploy/shared-components/home-index-service/`):
   - `auth/middleware.go` (new, ~100 lines) - Auth middleware
   - `auth/validator.go` (new, ~150 lines) - Firebase token validation
   - `main.go` (modify, ~50 lines) - Add auth middleware, env flag
   - `go.mod` (modify) - Add Firebase Admin SDK dependency

2. **Client-side** (HTML/JS):
   - `static/js/auth.js` (new, ~100 lines) - Firebase Auth integration
   - `static/js/auth-check.js` (new, ~50 lines) - Auth state checking
   - Template updates (modify, ~20 lines) - Include auth scripts conditionally

3. **Configuration**:
   - Environment variables in Cloud Run
   - Firebase Admin SDK credentials (service account key)

**Estimated effort: 4-6 hours**

## Security Considerations

### ✅ Good Practices
- Server-side token validation (never trust client-only)
- Token expiration checking
- Secure cookie flags (if using cookies)
- CORS configuration
- Rate limiting on auth endpoints

### ⚠️ Potential Issues
- Token exposure in URLs (if using URL params)
- XSS vulnerabilities (if tokens in localStorage)
- CSRF protection needed
- Token refresh handling

## Environment Configuration

### Development (No Auth)
```bash
ENABLE_AUTH=false
```

### Staging (Optional Auth)
```bash
ENABLE_AUTH=true
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_ADMIN_KEY=path/to/service-account.json
```

### Production (Auth Required)
```bash
ENABLE_AUTH=true
REQUIRE_AUTH=true  # Blocks unauthenticated access
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_ADMIN_KEY=path/to/service-account.json
```

## User Experience Flow

### With Auth Enabled
1. User visits `labs.pcioasis.com`
2. If not authenticated:
   - Show "Sign in required" message
   - Link to `www.pcioasis.com/sign-in`
   - After sign-in, redirect back to labs
3. If authenticated:
   - Seamless access to all labs
   - User info displayed (optional)

### With Auth Disabled
1. User visits `labs.pcioasis.com`
2. Full access (current behavior)
3. No authentication checks

## Testing Considerations

### Unit Tests
- Token validation logic
- Middleware behavior
- Environment flag handling

### Integration Tests
- Cross-domain token sharing
- Auth state persistence
- Redirect flows

### E2E Tests (Playwright)
- Sign in at www.pcioasis.com
- Navigate to labs.pcioasis.com
- Verify authenticated access
- Test logout flow

## Maintenance Overhead

### Low
- Firebase Admin SDK updates (rare)
- Token validation logic (stable)
- Environment configuration (simple)

### Medium
- Token refresh handling
- Error handling and edge cases
- Security updates

## Recommendation

**Proceed with implementation** using the **Hybrid Approach (Option 1 + Option 3)**:

1. ✅ **Low complexity** - Mostly additive changes
2. ✅ **Optional per environment** - Easy to toggle
3. ✅ **Minimal impact** on e-skimming-app
4. ✅ **Secure** - Server-side validation
5. ✅ **Maintainable** - Standard Firebase patterns

**Estimated Total Effort: 5-8 hours**

**Risk Level: Low** - Changes are isolated and optional

## Next Steps

1. Create detailed implementation plan
2. Set up Firebase Admin SDK in Go server
3. Implement auth middleware
4. Add client-side Firebase Auth integration
5. Add environment-based feature flags
6. Test cross-domain SSO flow
7. Update deployment configurations

