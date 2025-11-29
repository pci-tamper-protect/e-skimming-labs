# Production Navigation Architecture

This document explains how navigation works in production for the E-Skimming Labs platform, with a focus on verifying writeup page navigation.

## Overview

The E-Skimming Labs platform uses a **centralized home-index service** (Go application) that serves as the main entry point and handles routing for lab writeups. Individual lab pages (served by separate Cloud Run services) use client-side JavaScript to generate environment-aware URLs.

## Architecture Components

### 1. Home Index Service (`home-index-service`)

**Location**: `deploy/shared-components/home-index-service/main.go`

**Purpose**: 
- Serves the main landing page at `https://labs.pcioasis.com/`
- Handles writeup page routing at `/lab-01-writeup`, `/lab-02-writeup`, `/lab-03-writeup`
- Generates lab URLs for the home page

**Key Functions**:
- `serveHomePage()`: Renders the main landing page with lab cards
- `serveLabWriteup()`: Renders lab writeup pages from README.md files
- URL generation logic for production vs. local development

### 2. Lab Services (Cloud Run)

Each lab is deployed as a separate Cloud Run service:
- **Lab 1**: `lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app`
- **Lab 2**: `lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app`
- **Lab 3**: `lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app`

Each lab service:
- Serves the vulnerable site HTML/JS/CSS
- Uses client-side JavaScript to detect environment and generate navigation URLs
- Links back to the home-index service for writeup pages

## Navigation Flow

### From Home Page to Lab

1. **User clicks "Start Lab"** on home page
2. **Home page generates lab URL** based on environment:
   - **Production**: Direct Cloud Run URL (e.g., `https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app/`)
   - **Local**: Port-based URL (e.g., `http://localhost:9001/`)

3. **Lab-specific URL patterns**:
   - Lab 1: Root path `/` (serves `index.html`)
   - Lab 2: `/banking.html` (explicit path)
   - Lab 3: `/index.html` (explicit path)

**Code Reference** (`main.go` lines 143-171):
```go
if lab1URL == "" {
    if isLocal && lab1Domain != "" {
        lab1URL = fmt.Sprintf("%s://%s/", scheme, lab1Domain)
    } else {
        lab1URL = "https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app/"
    }
}
if lab2URL == "" {
    if isLocal && lab2Domain != "" {
        lab2URL = fmt.Sprintf("%s://%s/", scheme, lab2Domain)
    } else {
        lab2URL = "https://lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app/banking.html"
    }
}
if lab3URL == "" {
    if isLocal && lab3Domain != "" {
        lab3URL = fmt.Sprintf("%s://%s/", scheme, lab3Domain)
    } else {
        lab3URL = "https://lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app/index.html"
    }
}
```

### From Lab Page to Writeup Page

1. **User clicks "📖 Writeup" button** on lab page
2. **Client-side JavaScript detects environment** and generates writeup URL:
   - **Production**: `https://labs.pcioasis.com/lab-XX-writeup`
   - **Local**: `http://localhost:3000/lab-XX-writeup`

3. **Writeup URL is generated** based on hostname detection:
   - If hostname includes `lab-XX-*` or `run.app`: Uses `labs.pcioasis.com` domain
   - If hostname is `localhost` or `127.0.0.1`: Uses `localhost:3000`
   - Otherwise: Fallback logic

**Code Reference** (Lab 1 example, `index.html`):
```javascript
if (hostname.includes('lab-01-basic-magecart')) {
    // Production Cloud Run
    writeupUrl = 'https://labs.pcioasis.com/lab-01-writeup'
} else if (isLocal) {
    writeupUrl = 'http://localhost:3000/lab-01-writeup'
}
```

4. **Home-index service handles writeup route**:
   - Route: `/lab-01-writeup`, `/lab-02-writeup`, `/lab-03-writeup`
   - Handler: `serveLabWriteup()` function
   - Reads README.md from `/app/docs/labs/{lab-id}/README.md`
   - Renders markdown to HTML server-side
   - Generates "Back to Lab" URL based on environment

**Code Reference** (`main.go` lines 238-248):
```go
http.HandleFunc("/lab-01-writeup", func(w http.ResponseWriter, r *http.Request) {
    serveLabWriteup(w, r, "01-basic-magecart", lab1URL, homeData)
})

http.HandleFunc("/lab-02-writeup", func(w http.ResponseWriter, r *http.Request) {
    serveLabWriteup(w, r, "02-dom-skimming", lab2URL, homeData)
})

http.HandleFunc("/lab-03-writeup", func(w http.ResponseWriter, r *http.Request) {
    serveLabWriteup(w, r, "03-extension-hijacking", lab3URL, homeData)
})
```

### From Writeup Page Back to Lab

1. **User clicks "← Back to Lab" button** on writeup page
2. **Server-side Go code generates lab URL**:
   - Uses `labURL` parameter passed to `serveLabWriteup()`
   - Falls back to hardcoded production URLs if `labURL` is empty
   - Environment detection based on request hostname

**Code Reference** (`main.go` lines 832-861):
```go
// Determine lab URL for "Back to Lab" button
labBackURL := labURL
if labBackURL == "" {
    hostname := r.Host
    isLocal := hostname == "localhost:3000" || hostname == "127.0.0.1:3000"
    
    switch labID {
    case "01-basic-magecart":
        if isLocal {
            labBackURL = "http://localhost:9001/"
        } else {
            labBackURL = "https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app/"
        }
    case "02-dom-skimming":
        if isLocal {
            labBackURL = "http://localhost:9003/banking.html"
        } else {
            labBackURL = "https://lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app/banking.html"
        }
    case "03-extension-hijacking":
        if isLocal {
            labBackURL = "http://localhost:9005/index.html"
        } else {
            labBackURL = "https://lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app/index.html"
        }
    }
}
```

## Writeup Page Navigation Verification

### ✅ Verification Checklist

#### 1. Writeup URL Generation (Lab → Writeup)

**Lab 1** (`labs/01-basic-magecart/vulnerable-site/index.html`):
- ✅ Production: `https://labs.pcioasis.com/lab-01-writeup`
- ✅ Local: `http://localhost:3000/lab-01-writeup`
- ✅ Detection: Checks for `lab-01-basic-magecart` in hostname

**Lab 2** (`labs/02-dom-skimming/vulnerable-site/banking.html`):
- ✅ Production: `https://labs.pcioasis.com/lab-02-writeup`
- ✅ Local: `http://localhost:3000/lab-02-writeup`
- ✅ Detection: Checks for `lab-02-dom-skimming` or `run.app` with `lab-02`

**Lab 3** (`labs/03-extension-hijacking/vulnerable-site/index.html`):
- ✅ Production: `https://labs.pcioasis.com/lab-03-writeup`
- ✅ Local: `http://localhost:3000/lab-03-writeup`
- ✅ Detection: Checks for `lab-03-extension-hijacking` or `run.app` with `lab-03`

#### 2. Writeup Route Handling (Home-Index Service)

**Routes** (`main.go` lines 238-248):
- ✅ `/lab-01-writeup` → `serveLabWriteup("01-basic-magecart", lab1URL, homeData)`
- ✅ `/lab-02-writeup` → `serveLabWriteup("02-dom-skimming", lab2URL, homeData)`
- ✅ `/lab-03-writeup` → `serveLabWriteup("03-extension-hijacking", lab3URL, homeData)`

**Writeup URL Generation** (`main.go` lines 214-223):
- ✅ Lab 1: `{scheme}://{domain}/lab-01-writeup`
- ✅ Lab 2: `{scheme}://{domain}/lab-02-writeup`
- ✅ Lab 3: `{scheme}://{domain}/lab-03-writeup`

Where:
- `scheme` = `https` (production) or `http` (local)
- `domain` = `labs.pcioasis.com` (production) or `localhost:3000` (local)

#### 3. Back to Lab URL Generation (Writeup → Lab)

**Lab 1** (`main.go` lines 840-845):
- ✅ Production: `https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app/`
- ✅ Local: `http://localhost:9001/`

**Lab 2** (`main.go` lines 846-852):
- ✅ Production: `https://lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app/banking.html`
- ✅ Local: `http://localhost:9003/banking.html`

**Lab 3** (`main.go` lines 853-859):
- ✅ Production: `https://lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app/index.html`
- ✅ Local: `http://localhost:9005/index.html`

## Production URLs Summary

### Home Index Service
- **Production**: `https://labs.pcioasis.com`
- **Local**: `http://localhost:3000`

### Lab Services
- **Lab 1**: `https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app/`
- **Lab 2**: `https://lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app/banking.html`
- **Lab 3**: `https://lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app/index.html`

### Writeup Pages
- **Lab 1**: `https://labs.pcioasis.com/lab-01-writeup`
- **Lab 2**: `https://labs.pcioasis.com/lab-02-writeup`
- **Lab 3**: `https://labs.pcioasis.com/lab-03-writeup`

## Navigation Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Home Index Service                        │
│              https://labs.pcioasis.com/                     │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │ Lab 1    │  │ Lab 2    │  │ Lab 3    │                 │
│  │ Start    │  │ Start    │  │ Start    │                 │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                 │
└───────┼─────────────┼─────────────┼────────────────────────┘
        │             │             │
        ▼             ▼             ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Lab 1 Cloud  │ │ Lab 2 Cloud  │ │ Lab 3 Cloud  │
│ Run Service  │ │ Run Service  │ │ Run Service  │
│              │ │              │ │              │
│ [Writeup] ───┼─┼──────────────┼─┼──────────────┼──┐
└──────────────┘ └──────────────┘ └──────────────┘  │
                                                   │
                                                   ▼
                                    ┌──────────────────────────┐
                                    │  Home Index Service      │
                                    │  /lab-XX-writeup         │
                                    │                          │
                                    │  [Back to Lab] ──────────┼──┐
                                    └──────────────────────────┘  │
                                                                  │
                                                                  ▼
                                                    ┌─────────────────────┐
                                                    │  Lab Cloud Run      │
                                                    │  Service            │
                                                    └─────────────────────┘
```

## Key Design Decisions

1. **Centralized Writeup Routing**: All writeup pages are served by the home-index service, not individual lab services. This ensures consistent navigation and allows writeups to be updated independently.

2. **Environment-Aware URLs**: Both server-side (Go) and client-side (JavaScript) code detect the environment and generate appropriate URLs. This allows the same codebase to work in both local development and production.

3. **Explicit Lab Paths**: Lab 2 and Lab 3 use explicit paths (`/banking.html`, `/index.html`) in production to ensure correct routing, while Lab 1 uses the root path with nginx `index` directive.

4. **Fallback Logic**: Multiple layers of fallback ensure navigation works even if environment detection fails:
   - Primary: Use passed `labURL` parameter
   - Secondary: Environment-based hardcoded URLs
   - Tertiary: Hostname-based detection

## Testing Navigation

### Manual Testing Steps

1. **Home → Lab → Writeup → Lab**:
   - Navigate to `https://labs.pcioasis.com/`
   - Click "Start Lab" for any lab
   - Click "📖 Writeup" button
   - Verify writeup page loads
   - Click "← Back to Lab" button
   - Verify return to correct lab page

2. **Direct Writeup Access**:
   - Navigate directly to `https://labs.pcioasis.com/lab-01-writeup`
   - Verify page loads correctly
   - Click "← Back to Lab"
   - Verify navigation to Lab 1

### Automated Testing

Playwright tests verify navigation:
- Test: `should navigate to writeup page and back to lab`
- Location: Each lab's test suite
- Verifies: Lab → Writeup → Lab navigation flow

## Conclusion

✅ **All writeup navigation is correctly configured for production:**

1. ✅ Lab pages generate correct writeup URLs pointing to `labs.pcioasis.com`
2. ✅ Home-index service handles writeup routes correctly
3. ✅ Writeup pages generate correct "Back to Lab" URLs pointing to Cloud Run services
4. ✅ Environment detection works for both local and production
5. ✅ All three labs follow consistent navigation patterns

The navigation architecture is production-ready and verified.
