# Routing Refactor Plan: Remove Environment-Aware URL Configuration

## Problem Statement

**Current Issue:** JavaScript inside lab containers is performing environment detection and constructing URLs based on hostname. This violates the core Traefik design principle:

> **Traefik handles ALL routing. Services should be simple and not know about routing.**

### Current Violations

1. **Environment Detection in Containers**
   - JavaScript checks `window.location.hostname`
   - Determines if localhost, staging, or production
   - Constructs URLs based on environment

2. **Complex Fallback Logic**
   - Multiple conditional branches
   - Hardcoded domain names
   - Environment-specific URL construction

3. **Inconsistent Behavior**
   - Different URL patterns across environments
   - Containers need to "know" about routing
   - Makes debugging harder

### Files Affected

Found **22+ files** with "Environment-aware URL configuration":
- `labs/01-basic-magecart/vulnerable-site/index.html`
- `labs/01-basic-magecart/vulnerable-site/checkout*.html` (multiple variants)
- `labs/02-dom-skimming/vulnerable-site/banking*.html`
- `labs/03-extension-hijacking/vulnerable-site/index*.html`
- `labs/*/malicious-code/c2-server/dashboard.html`
- And more...

## Design Principle

**Core Principle:** Traefik handles routing. Services use relative paths only.

### Correct Pattern

```html
<!-- ✅ CORRECT: Simple relative paths -->
<base href="/lab1/" />
<a href="/">Back to Labs</a>
<a href="/lab1/c2">C2 Dashboard</a>
<a href="/lab-01-writeup">Writeup</a>
```

### Incorrect Pattern (Current)

```javascript
// ❌ WRONG: Environment detection and URL construction
const hostname = window.location.hostname
let baseUrl
if (hostname === 'localhost') {
  baseUrl = 'http://localhost:8080'
} else if (hostname === 'labs.stg.pcioasis.com') {
  baseUrl = ''
} else {
  baseUrl = 'https://labs.pcioasis.com'
}
const homeUrl = baseUrl + '/'
```

## Solution: Always Use Relative Paths

### Strategy

1. **Remove all environment detection** from JavaScript
2. **Use relative paths** for all navigation
3. **Leverage `<base href>` tag** for path resolution
4. **Let Traefik handle routing** - it already does!

### Why This Works

- **Traefik strips prefixes** (e.g., `/lab1` → `/` for lab service)
- **Relative paths work** because browser resolves them relative to current location
- **`<base href>` tag** ensures relative paths resolve correctly
- **No environment detection needed** - same code works everywhere

## Implementation Plan

### Phase 1: Analysis & Documentation

- [x] Identify all files with environment-aware URL configuration
- [x] Document current patterns
- [x] Create refactor plan
- [ ] Review with team

### Phase 2: Refactor Lab HTML Files

**Pattern to Replace:**

```javascript
// OLD: Environment-aware URL configuration
;(function () {
  const hostname = window.location.hostname
  let baseUrl
  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    baseUrl = 'http://localhost:8080'
  } else if (hostname === 'labs.stg.pcioasis.com' || hostname === 'labs.pcioasis.com') {
    baseUrl = ''
  } else {
    baseUrl = window.location.origin
  }
  
  const homeUrl = baseUrl + '/'
  const c2Url = baseUrl + '/lab1/c2'
  const writeupUrl = baseUrl + '/lab-01-writeup'
  
  document.querySelector('.back-button').href = homeUrl
  document.querySelector('.c2-button').href = c2Url
  document.querySelector('.writeup-button').href = writeupUrl
})()
```

**New Pattern:**

```html
<!-- Use <base href> for path resolution -->
<base href="/lab1/" />

<!-- Use relative paths directly in HTML -->
<a href="/" class="back-button">← Back to Labs</a>
<a href="/lab1/c2" class="c2-button">🕵️ View Stolen Data</a>
<a href="/lab-01-writeup" class="writeup-button">📖 Writeup</a>

<!-- Or minimal JavaScript if needed for dynamic updates -->
<script>
  // Simple relative path assignment (no environment detection)
  document.querySelector('.back-button').href = '/'
  document.querySelector('.c2-button').href = '/lab1/c2'
  document.querySelector('.writeup-button').href = '/lab-01-writeup'
</script>
```

### Phase 3: Update All Lab Files

**Files to Update:**

1. **Lab 1:**
   - `labs/01-basic-magecart/vulnerable-site/index.html`
   - `labs/01-basic-magecart/vulnerable-site/checkout.html`
   - `labs/01-basic-magecart/vulnerable-site/checkout_separate.html`
   - `labs/01-basic-magecart/vulnerable-site/checkout_single.html`
   - `labs/01-basic-magecart/vulnerable-site/checkout-train.html`
   - `labs/01-basic-magecart/malicious-code/c2-server/dashboard.html`
   - All variant files in `variants/` subdirectories

2. **Lab 2:**
   - `labs/02-dom-skimming/vulnerable-site/banking.html`
   - `labs/02-dom-skimming/vulnerable-site/banking-train.html`
   - `labs/02-dom-skimming/malicious-code/c2-server/dashboard.html`

3. **Lab 3:**
   - `labs/03-extension-hijacking/vulnerable-site/index.html`
   - `labs/03-extension-hijacking/vulnerable-site/index-train.html`
   - `labs/03-extension-hijacking/test-server/dashboard.html`

### Phase 4: Testing

**Test Scenarios:**

1. **Local Development (Docker Compose)** ✅
   - Navigate: `http://localhost:8080/lab1` → should work
   - Click "Back to Labs" → should go to `http://localhost:8080/`
   - Click "C2 Dashboard" → should go to `http://localhost:8080/lab1/c2`
   - Click "Writeup" → should go to `http://localhost:8080/lab-01-writeup`
   - **Status:** Tests run via `TEST_ENV=local npm test` in `labs/01-basic-magecart/test/`
   - **Results:** Check `test-results.json` and `playwright-report/index.html` (without opening browser)

2. **Staging (via Traefik)** ⏳
   - Navigate: `https://labs.stg.pcioasis.com/lab1` → should work
   - All navigation should use relative paths
   - No absolute Cloud Run URLs
   - **Status:** Pending - requires staging deployment and proxy setup
   - **Command:** `TEST_ENV=stg USE_PROXY=true npm test` (with proxy running)

3. **Production (via Traefik)** ⏳
   - Navigate: `https://labs.pcioasis.com/lab1` → should work
   - All navigation should use relative paths
   - **Status:** Pending - requires production deployment

4. **Direct Cloud Run Access (if still needed)**
   - Should still work (relative paths resolve to current origin)
   - But this should be discouraged

### Phase 5: Cleanup

- [ ] Remove unused environment detection code
- [ ] Update documentation
- [ ] Remove comments about "Environment-aware URL configuration"
- [ ] Update architecture docs to reflect new pattern

## Benefits

1. **Simpler Code**
   - No environment detection
   - No conditional logic
   - Easier to understand

2. **Consistent Behavior**
   - Same code works everywhere
   - No environment-specific bugs
   - Easier to debug

3. **Follows Design Principle**
   - Containers don't know about routing
   - Traefik handles all routing
   - Services are simple

4. **Better Maintainability**
   - Less code to maintain
   - Fewer edge cases
   - Clearer intent

## Risks & Mitigation

### Risk 1: Breaking Existing Functionality

**Mitigation:**
- Test thoroughly in all environments
- Keep old code commented initially
- Gradual rollout

### Risk 2: Direct Cloud Run Access

**Mitigation:**
- Relative paths still work (resolve to current origin)
- Document that direct access is discouraged
- Traefik is the primary entry point

### Risk 3: Browser Compatibility

**Mitigation:**
- `<base href>` is well-supported
- Relative paths are standard HTML
- Test in multiple browsers

## Migration Checklist

For each file:

- [ ] Remove environment detection JavaScript
- [ ] Replace with relative paths in HTML
- [ ] Ensure `<base href>` is set correctly
- [ ] Test navigation in local environment
- [ ] Test navigation in staging (via proxy)
- [ ] Test navigation in production
- [ ] Update any related documentation

## Example Refactor

### Before

```html
<script>
  // Environment-aware URL configuration with uniform path-based routing
  ;(function () {
    const hostname = window.location.hostname
    let baseUrl
    if (hostname === 'localhost' || hostname === '127.0.0.1') {
      baseUrl = 'http://localhost:8080'
    } else if (hostname === 'labs.stg.pcioasis.com' || hostname === 'labs.pcioasis.com') {
      baseUrl = ''
    } else {
      baseUrl = window.location.origin
    }
    
    const homeUrl = baseUrl + '/'
    const c2Url = baseUrl + '/lab1/c2'
    const writeupUrl = baseUrl + '/lab-01-writeup'
    
    document.querySelector('.back-button').href = homeUrl
    document.querySelector('.c2-button').href = c2Url
    document.querySelector('.writeup-button').href = writeupUrl
  })()
</script>
```

### After

```html
<base href="/lab1/" />

<!-- In HTML -->
<a href="/" class="back-button">← Back to Labs</a>
<a href="/lab1/c2" class="c2-button">🕵️ View Stolen Data</a>
<a href="/lab-01-writeup" class="writeup-button">📖 Writeup</a>

<!-- Or minimal JS if links are dynamically created -->
<script>
  document.querySelector('.back-button').href = '/'
  document.querySelector('.c2-button').href = '/lab1/c2'
  document.querySelector('.writeup-button').href = '/lab-01-writeup'
</script>
```

## Next Steps

1. **Review this plan** with the team
2. **Start with one lab** (Lab 1) as proof of concept
3. **Test thoroughly** before rolling out to all labs
4. **Update documentation** as we go
5. **Remove old code** once verified

---

**Status:** Planning Phase  
**Created:** 2026-01-08  
**Owner:** TBD
