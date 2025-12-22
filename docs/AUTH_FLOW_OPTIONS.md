# Authentication Flow Options Analysis

## Current State

**Current Flow:**
1. User visits `labs.pcioasis.com`
2. Labs checks for token → not found
3. Redirects to `www.pcioasis.com/sign-in?url=labs.pcioasis.com`
4. User signs in on main app
5. Main app redirects to `labs.pcioasis.com?token=...`
6. Labs picks up token and authenticates

**Issues:**
- Requires full page redirect between domains
- Feels clunky with multiple redirects
- User sees URL changes and page reloads

## Option 1: Labs Hosts Its Own Login Page ⭐ (Recommended)

**Approach:** Add `/sign-in` route to labs that uses the same Firebase project

**Implementation:**
- Create `labs.pcioasis.com/sign-in` page
- Use same Firebase config (same project ID)
- After login, redirect to labs dashboard/home
- Token stored in labs domain (no cross-domain issues)

**Pros:**
- ✅ No cross-domain redirects
- ✅ Seamless user experience
- ✅ Same Firebase project = same user accounts
- ✅ Can still share tokens via postMessage if needed
- ✅ Users stay on labs domain

**Cons:**
- ⚠️ Need to maintain login UI in two places (or share components)
- ⚠️ Slightly more code to maintain

**Code Changes:**
- Add sign-in page to `home-index-service`
- Use Firebase Auth SDK in labs
- Store token in `localStorage` on labs domain

---

## Option 2: Popup-Based Login (No Redirects)

**Approach:** Open login in popup window, communicate via postMessage

**Implementation:**
- Labs opens `www.pcioasis.com/sign-in` in popup
- User signs in in popup
- Popup sends token to labs via postMessage
- Labs receives token and closes popup

**Pros:**
- ✅ No full-page redirects
- ✅ User stays on labs page
- ✅ Seamless experience

**Cons:**
- ⚠️ Popup blockers may interfere
- ⚠️ Mobile experience can be tricky
- ⚠️ More complex error handling

**Code Changes:**
- Update labs auth script to open popup
- Update sign-in page to send token via postMessage
- Handle popup communication

---

## Option 3: Shared Auth Subdomain

**Approach:** Use `auth.pcioasis.com` for authentication, both sites redirect there

**Implementation:**
- Create dedicated auth subdomain
- Both `www` and `labs` redirect to `auth.pcioasis.com/sign-in`
- After login, redirect back to originating site
- Token stored in auth domain, shared via cookies or postMessage

**Pros:**
- ✅ Centralized auth logic
- ✅ Single login UI to maintain
- ✅ Can use same-site cookies (all on pcioasis.com)

**Cons:**
- ⚠️ Requires new subdomain setup
- ⚠️ Still requires redirects (but to dedicated auth domain)
- ⚠️ More infrastructure complexity

**Code Changes:**
- Create new auth service
- Update both sites to redirect to auth subdomain
- Implement cookie-based token sharing

---

## Option 4: Improved PostMessage SSO (Current + Enhancements)

**Approach:** Enhance current postMessage flow to be more seamless

**Implementation:**
- Labs immediately requests token from main app via postMessage
- If main app has token, send it immediately (no redirect needed)
- Only redirect if no token exists
- Use iframe for silent token refresh

**Pros:**
- ✅ Minimal changes to current setup
- ✅ Works if user already logged into main app
- ✅ No redirects if token available

**Cons:**
- ⚠️ Still requires redirect for new logins
- ⚠️ postMessage has security considerations
- ⚠️ Iframe approach can be blocked

**Code Changes:**
- Enhance postMessage listener in labs
- Add silent iframe for token checking
- Improve error handling

---

## Option 5: Cookie-Based SSO (Same-Site Cookies)

**Approach:** Use same-site cookies since both are on `pcioasis.com`

**Implementation:**
- Set cookie with domain `.pcioasis.com` (available to all subdomains)
- Both sites read from same cookie
- No postMessage or redirects needed

**Pros:**
- ✅ Most seamless experience
- ✅ No redirects or popups
- ✅ Native browser support

**Cons:**
- ⚠️ Security considerations (cookie exposure)
- ⚠️ Firebase tokens in cookies (need secure/httpOnly flags)
- ⚠️ Requires server-side cookie setting

**Code Changes:**
- Backend sets secure cookie after Firebase auth
- Both sites read cookie on page load
- Implement token refresh via cookie

---

## Option 6: Separate Auth Systems (No SSO)

**Approach:** Labs has its own Firebase project, separate user accounts

**Implementation:**
- Create separate Firebase project for labs
- Labs manages its own authentication
- No integration with main app

**Pros:**
- ✅ Complete independence
- ✅ No cross-domain complexity
- ✅ Can have different auth requirements

**Cons:**
- ❌ Users need separate accounts
- ❌ No SSO benefits
- ❌ More user friction

---

## Recommendation: Option 1 (Labs Hosts Login) + Option 4 (Enhanced SSO)

**Hybrid Approach:**

1. **Labs has its own `/sign-in` page** for new logins
   - Uses same Firebase project
   - Seamless experience, no redirects
   - User stays on labs domain

2. **Enhanced postMessage SSO** for existing sessions
   - If user already logged into main app, use that token
   - Silent token sharing via postMessage
   - No redirects if token available

3. **Fallback to main app** if needed
   - If labs login fails, can redirect to main app
   - Maintains current flow as backup

**Benefits:**
- ✅ Best user experience (no redirects for new logins)
- ✅ SSO still works (token sharing for existing sessions)
- ✅ Flexible (can use either approach)
- ✅ Maintains single user account system

**Implementation Priority:**
1. Add labs sign-in page (Option 1)
2. Enhance postMessage SSO (Option 4)
3. Keep main app redirect as fallback

---

## Quick Comparison

| Option | Redirects | SSO | Complexity | User Experience |
|--------|-----------|-----|------------|-----------------|
| 1. Labs Login | ❌ None | ✅ Yes | Medium | ⭐⭐⭐⭐⭐ |
| 2. Popup | ❌ None | ✅ Yes | High | ⭐⭐⭐⭐ |
| 3. Auth Subdomain | ⚠️ One | ✅ Yes | High | ⭐⭐⭐ |
| 4. Enhanced SSO | ⚠️ Sometimes | ✅ Yes | Low | ⭐⭐⭐⭐ |
| 5. Cookies | ❌ None | ✅ Yes | Medium | ⭐⭐⭐⭐⭐ |
| 6. Separate | ❌ None | ❌ No | Low | ⭐⭐ |

---

## Next Steps

If proceeding with **Option 1 (Labs Login)**:

1. Create sign-in page component in `home-index-service`
2. Add Firebase Auth SDK to labs
3. Implement sign-in route handler
4. Update auth script to use local login first, fallback to main app
5. Test SSO token sharing still works

Would you like me to implement Option 1, or discuss any of these options further?

