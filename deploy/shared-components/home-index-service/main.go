package main

/*
 * ============================================================================
 * ROUTING ARCHITECTURE PRINCIPLE - DO NOT REGRESS
 * ============================================================================
 *
 * **CRITICAL**: Services MUST NOT contain routing logic. All routing belongs to Traefik.
 *
 * Services should ALWAYS return relative URLs for navigation:
 *   - Lab URLs: /lab1, /lab2, /lab3
 *   - Navigation: /mitre-attack, /threat-model, /sign-in
 *   - Writeups: /lab-01-writeup, /lab-02-writeup, /lab-03-writeup
 *
 * Traefik handles all routing based on path prefixes:
 *   - /lab1 → routes to lab1 service
 *   - /lab2 → routes to lab2 service
 *   - /lab3 → routes to lab3 service
 *   - /mitre-attack → routes to home-index service
 *   - /sign-in → routes to appropriate service
 *
 * **DO NOT** add logic to:
 *   - Detect if service is behind Traefik (isBehindTraefik, isProxyHost, etc.)
 *   - Conditionally use relative vs absolute URLs (useRelativeURLs)
 *   - Check X-Forwarded-Host or X-Forwarded-For for routing decisions
 *   - Generate different URLs based on environment (local vs staging vs production)
 *
 * **EXCEPTION**: Absolute URLs are ONLY allowed for SEO metadata:
 *   - Canonical tags: <link rel="canonical" href="https://domain.com/">
 *   - Open Graph tags: <meta property="og:url" content="https://domain.com/">
 *
 * If you find yourself adding routing logic to a service, STOP and ask:
 * "Why can't Traefik handle this routing?"
 *
 * ============================================================================
 */

import (
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"time"

	"home-index-service/auth"

	"github.com/gomarkdown/markdown"
	"github.com/gomarkdown/markdown/html"
	"gopkg.in/yaml.v3"
)

type Lab struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Difficulty  string `json:"difficulty"`
	URL         string `json:"url"`
	WriteupURL  string `json:"writeupUrl"`
	Status      string `json:"status"`
}

type HomePageData struct {
	Environment      string
	Domain           string
	LabsDomain       string
	MainDomain       string
	LabsProjectID    string
	Scheme           string
	Labs             []Lab
	MITREURL         string
	ThreatModelURL   string
	CatalogInfo      *CatalogInfo
	AuthEnabled      bool
	AuthRequired     bool
	FirebaseProjectID string
	MainAppURL       string
	UserEmail        string
	UserID           string
}

type ServiceStatus struct {
	Name   string `json:"name"`
	Status string `json:"status"` // "up", "down", "starting"
	URL    string `json:"url,omitempty"`
}

type StatusPageData struct {
	Services      []ServiceStatus
	AllReady      bool
	APIUnavailable bool
	Environment   string
	RefreshURL    string
	DashboardURL  string
}

// CatalogInfo represents the catalog metadata
type CatalogInfo struct {
	PTP struct {
		Service struct {
			Name        string `yaml:"name"`
			Version     string `yaml:"version"`
			Environment string `yaml:"environment"`
		} `yaml:"service"`
		Git struct {
			CommitSHAShort string `yaml:"commit_sha_short"`
			CommitAuthor   string `yaml:"commit_author"`
			Branch         string `yaml:"branch"`
			CommitMessage  string `yaml:"commit_message"`
		} `yaml:"git"`
	} `yaml:"ptp"`
}

// loadCatalogInfo loads catalog information from catalog-info.yaml
func loadCatalogInfo() *CatalogInfo {
	data, err := os.ReadFile("/app/catalog-info.yaml")
	if err != nil {
		log.Printf("⚠️ Could not load catalog info: %v", err)
		return nil
	}

	var catalogInfo CatalogInfo
	if err := yaml.Unmarshal(data, &catalogInfo); err != nil {
		log.Printf("⚠️ Could not parse catalog info: %v", err)
		return nil
	}

	return &catalogInfo
}

// sanitizeForLog removes newlines and carriage returns from a string to prevent log injection,
// and optionally truncates to maxLen characters to prevent log flooding.
// If maxLen is 0, no truncation is applied.
func sanitizeForLog(s string, maxLen int) string {
	safe := strings.ReplaceAll(strings.ReplaceAll(s, "\n", ""), "\r", "")
	if maxLen > 0 && len(safe) > maxLen {
		return safe[:maxLen] + "...[truncated]"
	}
	return safe
}

// sanitizeToken returns a redacted version of a token showing only first 10% and last 10%
// with the length, to prevent exposing sensitive credentials in logs while still being useful for debugging.
func sanitizeToken(token string) string {
	if token == "" {
		return "[empty]"
	}
	length := len(token)
	if length <= 20 {
		// For very short tokens, just show length
		return fmt.Sprintf("[token len=%d]", length)
	}
	// Show first 10% and last 10%
	showLen := length / 10
	if showLen < 4 {
		showLen = 4
	}
	if showLen > 20 {
		showLen = 20
	}
	return fmt.Sprintf("%s...%s [len=%d]", token[:showLen], token[length-showLen:], length)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Load catalog information
	catalogInfo := loadCatalogInfo()
	if catalogInfo != nil {
		log.Printf("🚀 Starting %s v%s",
			catalogInfo.PTP.Service.Name,
			catalogInfo.PTP.Service.Version)
		log.Printf("🔗 Git commit: %s (%s) by %s",
			catalogInfo.PTP.Git.CommitSHAShort,
			catalogInfo.PTP.Git.Branch,
			catalogInfo.PTP.Git.CommitAuthor)
		if catalogInfo.PTP.Git.CommitMessage != "" {
			log.Printf("📝 Commit message: %s", catalogInfo.PTP.Git.CommitMessage)
		}
	} else {
		log.Printf("🚀 Starting E-Skimming Labs (catalog info not available)")
	}

	// Get environment variables
	environment := os.Getenv("ENVIRONMENT")
	domain := os.Getenv("DOMAIN")
	labsDomain := os.Getenv("LABS_DOMAIN")
	// Lab URLs are no longer needed - services always use relative URLs (/lab1, /lab2, /lab3)
	// Traefik handles routing based on path prefixes
	mainDomain := os.Getenv("MAIN_DOMAIN")
	labsProjectID := os.Getenv("LABS_PROJECT_ID")

	// Set default values
	if domain == "" {
		domain = "labs.pcioasis.com"
	}
	if labsDomain == "" {
		labsDomain = "labs.pcioasis.com"
	}

	// Determine MAIN_DOMAIN based on environment if not explicitly set
	if mainDomain == "" {
		switch environment {
		case "local":
			// For local, use the DOMAIN (localhost:8080) for sign-in
			mainDomain = domain
		case "stg":
			// For staging, use labs.stg.pcioasis.com
			mainDomain = "labs.stg.pcioasis.com"
		case "prd":
			// For production, use labs.pcioasis.com
			mainDomain = "labs.pcioasis.com"
		default:
			// Default to production domain
			mainDomain = "labs.pcioasis.com"
		}
	}
	// Lab domains no longer needed - services use relative URLs (/lab1, /lab2, /lab3)
	// MAIN_DOMAIN is set above based on environment if not explicitly provided
	// Default to empty - should be set via environment variable
	// This allows staging to use labs-stg and production to use labs-prd
	if labsProjectID == "" {
		// Log warning but don't set default - let the service fail if not configured
		log.Printf("WARNING: LABS_PROJECT_ID not set. This must be configured via environment variable.")
	}

	// Choose http for local/dev, https otherwise
	isLocal := strings.EqualFold(environment, "local") || strings.Contains(domain, "localhost") || strings.Contains(labsDomain, "localhost")
	scheme := "https"
	if isLocal {
		scheme = "http"
	}

	// Define available labs with detailed descriptions
	// IMPORTANT: Always use relative URLs for navigation - Traefik handles routing
	// DO NOT add logic to detect environment or proxy - just use relative paths
	// Environment variables (LAB1_URL, LAB2_URL, LAB3_URL) are ignored - we always use relative paths
	labs := []Lab{
		{
			ID:          "lab1-basic-magecart",
			Name:        "Basic Magecart Attack",
			Description: "Learn the fundamentals of payment card skimming attacks through JavaScript injection. Understand how attackers compromise e-commerce sites, intercept form submissions, and exfiltrate credit card data. Practice detection using browser DevTools and implement basic defensive measures.",
			Difficulty:  "Beginner",
			URL:         "/lab1", // Always relative - Traefik routes to lab1 service
			Status:      "Available",
		},
		{
			ID:          "lab2-dom-skimming",
			Name:        "DOM-Based Skimming",
			Description: "Master advanced DOM manipulation techniques for stealthy payment data capture. Learn real-time field monitoring, dynamic form injection, Shadow DOM abuse, and DOM tree manipulation. Understand how attackers bypass traditional detection methods.",
			Difficulty:  "Intermediate",
			URL:         "/lab2", // Always relative - Traefik routes to lab2 service
			Status:      "Available",
		},
		{
			ID:          "lab3-extension-hijacking",
			Name:        "Browser Extension Hijacking",
			Description: "Explore sophisticated browser extension-based attacks that exploit privileged APIs and persistent access. Learn about content script injection, background script persistence, cross-origin communication, and supply chain attacks through malicious extensions.",
			Difficulty:  "Advanced",
			URL:         "/lab3", // Always relative - Traefik routes to lab3 service
			Status:      "Available",
		},
	}

	// Create home page data
	// Use relative URLs for navigation - Traefik handles routing
	// Absolute URLs only needed for SEO metadata (canonical, og:url)
	homeData := HomePageData{
		Environment:    environment,
		Domain:         domain,
		LabsDomain:     labsDomain,
		MainDomain:     mainDomain,
		LabsProjectID:  labsProjectID,
		Scheme:         scheme,
		Labs:           labs,
		MITREURL:       "/mitre-attack",       // Always relative - Traefik routes
		ThreatModelURL: "/threat-model",       // Always relative - Traefik routes
		MainAppURL:     "",                    // Empty = use relative paths in templates
	}

	// Update labs with writeup URLs (always relative)
	for i := range homeData.Labs {
		switch homeData.Labs[i].ID {
		case "lab1-basic-magecart":
			homeData.Labs[i].WriteupURL = "/lab-01-writeup"
		case "lab2-dom-skimming":
			homeData.Labs[i].WriteupURL = "/lab-02-writeup"
		case "lab3-extension-hijacking":
			homeData.Labs[i].WriteupURL = "/lab-03-writeup"
		}
	}

	// Initialize authentication
	enableAuth := os.Getenv("ENABLE_AUTH") == "true"
	requireAuth := os.Getenv("REQUIRE_AUTH") == "true"
	firebaseProjectID := os.Getenv("FIREBASE_PROJECT_ID")
	// FIREBASE_SERVICE_ACCOUNT_KEY is the service account JSON (server-side Admin SDK)
	// FIREBASE_API_KEY is the Web API key (client-side Web SDK) - kept for backward compatibility
	firebaseServiceAccount := os.Getenv("FIREBASE_SERVICE_ACCOUNT_KEY")
	if firebaseServiceAccount == "" {
		// Fallback to FIREBASE_API_KEY if it looks like JSON (starts with {)
		firebaseAPIKey := os.Getenv("FIREBASE_API_KEY")
		if firebaseAPIKey != "" && strings.HasPrefix(strings.TrimSpace(firebaseAPIKey), "{") {
			firebaseServiceAccount = firebaseAPIKey
		} else if enableAuth {
			// If auth is enabled but no service account found, disable auth
			log.Printf("⚠️  FIREBASE_SERVICE_ACCOUNT_KEY not found and FIREBASE_API_KEY is not a service account JSON")
			log.Printf("   Disabling authentication (add FIREBASE_SERVICE_ACCOUNT_KEY to enable)")
			enableAuth = false
		}
	} else if strings.HasPrefix(strings.TrimSpace(firebaseServiceAccount), "encrypted:") {
		// Value is still encrypted (dotenvx decryption failed)
		log.Printf("⚠️  FIREBASE_SERVICE_ACCOUNT_KEY appears to be encrypted (starts with 'encrypted:')")
		log.Printf("   This usually means dotenvx decryption failed. Disabling authentication.")
		log.Printf("   To fix: Ensure DOTENV_PRIVATE_KEY_STG is set correctly when running docker-compose")
		enableAuth = false
		firebaseServiceAccount = "" // Clear the encrypted value
	}

	// MainAppURL is now empty (relative paths) - services always use relative URLs
	// IMPORTANT: Traefik handles routing, so services don't need to know about proxy setup
	// DO NOT add logic to detect environment or generate absolute URLs here
	mainAppURL := ""

	authConfig := auth.Config{
		Enabled:         enableAuth,
		RequireAuth:     requireAuth,
		ProjectID:       firebaseProjectID,
		CredentialsJSON: firebaseServiceAccount,
		MainAppURL:      mainAppURL, // Empty = use relative paths
	}

	authValidator, err := auth.NewTokenValidator(authConfig)
	if err != nil {
		log.Fatalf("Failed to initialize auth validator: %v", err)
	}

	// Add auth info to home page data
	homeData.AuthEnabled = enableAuth
	homeData.AuthRequired = requireAuth
	homeData.FirebaseProjectID = firebaseProjectID
	homeData.MainAppURL = mainAppURL // Empty = use relative paths (Traefik handles routing)

	// Create router with auth middleware
	mux := http.NewServeMux()

	// Define routes
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		serveHomePage(w, r, homeData, authValidator)
	})

	mux.HandleFunc("/mitre-attack", func(w http.ResponseWriter, r *http.Request) {
		serveMITREPage(w, r, homeData, authValidator)
	})

	// Serve static assets from docs directory (for mitre-attack-visual.html)
	mux.HandleFunc("/mitre-attack/private-data-loader.js", func(w http.ResponseWriter, r *http.Request) {
		serveDocsFile(w, r, "private-data-loader.js")
	})

	mux.HandleFunc("/threat-model", func(w http.ResponseWriter, r *http.Request) {
		serveThreatModelPage(w, r, homeData, authValidator)
	})

	mux.HandleFunc("/lab-01-writeup", func(w http.ResponseWriter, r *http.Request) {
		serveLabWriteup(w, r, "01-basic-magecart", homeData, authValidator)
	})

	mux.HandleFunc("/lab-02-writeup", func(w http.ResponseWriter, r *http.Request) {
		serveLabWriteup(w, r, "02-dom-skimming", homeData, authValidator)
	})

	mux.HandleFunc("/lab-03-writeup", func(w http.ResponseWriter, r *http.Request) {
		serveLabWriteup(w, r, "03-extension-hijacking", homeData, authValidator)
	})

	mux.HandleFunc("/api/labs", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(labs)
	})

	// Auth API endpoints
	mux.HandleFunc("/api/auth/validate", func(w http.ResponseWriter, r *http.Request) {
		serveAuthValidate(w, r, authValidator)
	})

	mux.HandleFunc("/api/auth/sign-in-url", func(w http.ResponseWriter, r *http.Request) {
		serveAuthSignInURL(w, r, homeData)
	})

	mux.HandleFunc("/api/auth/user", func(w http.ResponseWriter, r *http.Request) {
		serveAuthUser(w, r, authValidator)
	})

	// Auth check endpoint for Traefik ForwardAuth middleware
	// Returns 200 if authenticated, 302 redirect to sign-in for browser requests, 401 for API requests
	// Reference: https://doc.traefik.io/traefik/middlewares/http/forwardauth/
	mux.HandleFunc("/api/auth/check", func(w http.ResponseWriter, r *http.Request) {
		// This endpoint is called by Traefik ForwardAuth middleware
		// According to Traefik docs, ForwardAuth forwards headers specified in authRequestHeaders
		// Reference: https://github.com/traefik/traefik/blob/master/pkg/middlewares/forwardauth/forwardauth.go
		log.Printf("🔍 /api/auth/check called - Host: %s, X-Forwarded-Host: %s, X-Forwarded-For: %s",
			sanitizeForLog(r.Host, 200), sanitizeForLog(r.Header.Get("X-Forwarded-Host"), 200), sanitizeForLog(r.Header.Get("X-Forwarded-For"), 200))

		// DEBUG: Log ALL headers to see what Traefik ForwardAuth is actually forwarding
		// According to Traefik ForwardAuth implementation, it should forward headers listed in authRequestHeaders
		log.Printf("🔍 DEBUG: All headers received in /api/auth/check:")
		for name, values := range r.Header {
			// Log cookie header value preview (truncated for security)
			if strings.ToLower(name) == "cookie" {
				log.Printf("🔍   %s: %s", name, sanitizeToken(values[0]))
			} else if strings.ToLower(name) == "authorization" {
				log.Printf("🔍   %s: %s", name, sanitizeToken(strings.Join(values, ", ")))
			} else {
				log.Printf("🔍   %s: %v", name, sanitizeForLog(strings.Join(values, ", "), 200))
			}
		}

		// DEBUG: Log the request path and method to identify which route triggered this
		log.Printf("🔍 DEBUG: Request path: %s, method: %s, X-Forwarded-Uri: %s",
			r.URL.Path, r.Method, sanitizeForLog(r.Header.Get("X-Forwarded-Uri"), 200))

		if !authValidator.IsEnabled() {
			// Auth disabled, allow access
			w.WriteHeader(http.StatusOK)
			return
		}

		// IMPORTANT: Proxy detection here is ONLY for authentication bypass (local testing)
		// DO NOT use this for URL routing decisions - services always use relative URLs
		// Traefik handles all routing - services should never check X-Forwarded-Host for routing
	host := r.Host
	forwardedHost := r.Header.Get("X-Forwarded-Host")
	forwardedFor := r.Header.Get("X-Forwarded-For")
	environment := os.Getenv("ENVIRONMENT")
	labsDomain := os.Getenv("LABS_DOMAIN")
	if labsDomain == "" {
		labsDomain = "labs.pcioasis.com"
	}

	// Check if we're behind Traefik (for auth bypass detection)
	isBehindTraefik := strings.Contains(strings.ToLower(forwardedHost), "traefik") ||
		(labsDomain != "" && (host == labsDomain || forwardedHost == labsDomain || strings.HasSuffix(host, labsDomain) || strings.HasSuffix(forwardedHost, labsDomain)))

	// Check for direct proxy access (for local testing)
	isLocalProxy := strings.Contains(forwardedFor, "127.0.0.1") || strings.Contains(forwardedFor, "localhost")
	// Check for 8081 (local dev), 8082 (staging proxy), and 9090 (local Traefik) ports
	isProxyHost := host == "127.0.0.1:8081" || host == "localhost:8081" ||
		strings.HasSuffix(host, ":8081") ||
		host == "127.0.0.1:8082" || host == "localhost:8082" ||
		strings.HasSuffix(host, ":8082") ||
		host == "127.0.0.1:9090" || host == "localhost:9090" ||
		strings.HasSuffix(host, ":9090")
	isForwardedProxyHost := forwardedHost == "127.0.0.1:8081" || forwardedHost == "localhost:8081" ||
		strings.HasSuffix(forwardedHost, ":8081") ||
		forwardedHost == "127.0.0.1:8082" || forwardedHost == "localhost:8082" ||
		strings.HasSuffix(forwardedHost, ":8082") ||
		forwardedHost == "127.0.0.1:9090" || forwardedHost == "localhost:9090" ||
		strings.HasSuffix(forwardedHost, ":9090")

		// Bypass authentication for proxy access (local testing)
		// User is already authenticated to gcloud when using proxy
		log.Printf("🔍 Bypass check - env:%s, isProxy:%v, isFwdProxy:%v, isLocal:%v, isBehindTraefik:%v",
			environment, isProxyHost, isForwardedProxyHost, isLocalProxy, isBehindTraefik)

		if environment == "stg" && (isProxyHost || isForwardedProxyHost || isLocalProxy || isBehindTraefik) {
			log.Printf("🔓 Bypassing auth for proxy access (Host: %s, Forwarded-Host: %s, Forwarded-For: %s)",
				sanitizeForLog(host, 200), sanitizeForLog(forwardedHost, 200), sanitizeForLog(forwardedFor, 200))
			w.Header().Set("X-User-Id", "proxy-user")
			w.Header().Set("X-User-Email", "proxy@test.local")
			w.WriteHeader(http.StatusOK)
			return
		}

		// Extract token from request
		// Priority order:
		// 1. Cookie header (Firebase token) - prioritized when using gcloud proxy (gcloud sets Authorization)
		// 2. Authorization header (Firebase token) - for direct access
		// 3. Parsed Cookie (fallback)
		// 4. Query parameter (fallback)
		var token string
		
		// Check Cookie header first (when using gcloud proxy, Authorization is set by gcloud, not user)
		// This avoids trying to validate gcloud's GCP token as a Firebase token
		cookieHeader := r.Header.Get("Cookie")
		if cookieHeader != "" {
			log.Printf("🔍 Cookie header received: %s", sanitizeToken(cookieHeader))
			// Parse the Cookie header manually to extract firebase_token
			cookies := strings.Split(cookieHeader, ";")
			for _, c := range cookies {
				c = strings.TrimSpace(c)
				if strings.HasPrefix(c, "firebase_token=") {
					token = strings.TrimPrefix(c, "firebase_token=")
					log.Printf("🔍 Token extracted from Cookie header: %s", sanitizeToken(token))
					break
				}
			}
		}
		
		// Fallback to Authorization header if no Cookie token found (direct access scenario)
		if token == "" {
			authHeader := r.Header.Get("Authorization")
			if authHeader != "" {
				parts := strings.SplitN(authHeader, " ", 2)
				if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
					token = parts[1]
					log.Printf("🔍 Token found in Authorization header: %s", sanitizeToken(token))
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
				log.Printf("🔍 Token found in parsed cookie: %s (parts: %d)", sanitizeToken(token), len(strings.Split(token, ".")))
			} else {
				log.Printf("🔍 Cookie not found or empty: %v", err)
				// Also check all cookies for debugging
				allCookies := r.Cookies()
				log.Printf("🔍 All cookies received: %d cookies", len(allCookies))
				for _, c := range allCookies {
					log.Printf("🔍 Cookie: %s = %s", sanitizeForLog(c.Name, 50), sanitizeToken(c.Value))
				}
				// Also log all headers for debugging
				log.Printf("🔍 All request headers:")
				for name, values := range r.Header {
					if strings.ToLower(name) == "cookie" || strings.ToLower(name) == "authorization" {
						log.Printf("🔍   %s: %s", name, sanitizeToken(strings.Join(values, ", ")))
					} else {
						log.Printf("🔍   %s: %v", name, sanitizeForLog(strings.Join(values, ", "), 200))
					}
				}
			}
		}

		// Get original request URI from Traefik headers (needed for both token extraction and redirect)
		originalURI := r.Header.Get("X-Forwarded-Uri")
		if originalURI == "" {
			// Fallback to request path
			originalURI = r.URL.Path
			if r.URL.RawQuery != "" {
				originalURI += "?" + r.URL.RawQuery
			}
		}

		// Check for token in query parameters (check both current URL and forwarded URI)
		if token == "" {
			token = r.URL.Query().Get("token")
		}
		// Check X-Forwarded-Uri for token (Traefik forwards the original URI with query params)
		if token == "" && originalURI != "" {
			if parsedURI, err := url.Parse(originalURI); err == nil {
				token = parsedURI.Query().Get("token")
			}
		}

		// WORKAROUND: If no token found and this is a ForwardAuth request, check if cookie might be in sessionStorage
		// This is a fallback in case Traefik ForwardAuth doesn't forward cookies correctly
		// Note: This won't work for server-side requests, but helps diagnose the issue
		if token == "" {
			log.Printf("⚠️ WARNING: No token found in any source (Authorization, Cookie header, parsed cookie, or query params)")
			log.Printf("⚠️ This suggests Traefik ForwardAuth is not forwarding the Cookie header correctly")
			log.Printf("⚠️ Original URI: %s, Request path: %s", sanitizeForLog(originalURI, 200), r.URL.Path)
		}

		// Check if this is a browser request
		acceptHeader := r.Header.Get("Accept")
		isBrowserRequest := strings.Contains(acceptHeader, "text/html") ||
			acceptHeader == "" ||
			strings.Contains(acceptHeader, "*/*")

		// Build absolute URL for redirects - ForwardAuth resolves relative URLs against its own address
		// which causes browser to redirect to internal hostname (e.g., home-index:8080) instead of public hostname
		buildRedirectURL := func(path string) string {
			scheme := "http"
			if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
				scheme = "https"
			}
			// Get public hostname from X-Forwarded-Host
			host := r.Header.Get("X-Forwarded-Host")
			environment := os.Getenv("ENVIRONMENT")
			if host == "" || environment == "local" {
				// In local environment, always use localhost:8080
				// X-Forwarded-Host might be empty or set to internal hostname
				host = "localhost:8080"
			}
			return fmt.Sprintf("%s://%s%s", scheme, host, path)
		}

		if token == "" {
			// No token provided
			if isBrowserRequest {
				// Redirect browser requests to sign-in using absolute URL
				redirectPath := fmt.Sprintf("/sign-in?redirect=%s", url.QueryEscape(originalURI))
				redirectURL := buildRedirectURL(redirectPath)
				log.Printf("🔗 Redirecting to: %s (absolute URL for ForwardAuth)", sanitizeForLog(redirectURL, 200))
				w.Header().Set("Location", redirectURL)
				w.WriteHeader(http.StatusFound)
				return
			}
			w.WriteHeader(http.StatusUnauthorized)
			w.Header().Set("X-Auth-Error", "No token provided")
			return
		}

		// Validate token
		userInfo, err := authValidator.ValidateToken(r.Context(), token)
		if err != nil || userInfo == nil {
			if isBrowserRequest {
				// Redirect browser requests to sign-in using absolute URL
				redirectPath := fmt.Sprintf("/sign-in?redirect=%s", url.QueryEscape(originalURI))
				redirectURL := buildRedirectURL(redirectPath)
				log.Printf("🔗 Redirecting to: %s (absolute URL for ForwardAuth)", sanitizeForLog(redirectURL, 200))
				w.Header().Set("Location", redirectURL)
				w.WriteHeader(http.StatusFound)
				return
			}
			w.WriteHeader(http.StatusUnauthorized)
			w.Header().Set("X-Auth-Error", "Invalid token")
			return
		}

		// Authenticated - add user info to headers for downstream services
		w.Header().Set("X-User-Id", userInfo.UserID)
		w.Header().Set("X-User-Email", userInfo.Email)
		// Preserve the original JWT token in X-Authorization header
		// This allows backend services to access the raw Firebase token even after
		// service auth middleware overwrites the Authorization header
		w.Header().Set("X-Authorization", fmt.Sprintf("Bearer %s", token))
		w.WriteHeader(http.StatusOK)
	})

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// Status page endpoint (checks service health)
	mux.HandleFunc("/status", func(w http.ResponseWriter, r *http.Request) {
		serveStatusPage(w, r, homeData)
	})

	// Status API endpoint (returns JSON)
	mux.HandleFunc("/api/status", func(w http.ResponseWriter, r *http.Request) {
		serveStatusAPI(w, r, homeData)
	})

	// Serve static auth scripts
	mux.HandleFunc("/static/js/auth.js", func(w http.ResponseWriter, r *http.Request) {
		serveAuthJS(w, r, homeData)
	})

	mux.HandleFunc("/static/js/auth-check.js", func(w http.ResponseWriter, r *http.Request) {
		serveAuthCheckJS(w, r)
	})

	// Sign-in and sign-up pages (public, no auth required)
	mux.HandleFunc("/sign-in", func(w http.ResponseWriter, r *http.Request) {
		serveSignInPage(w, r, homeData)
	})

	mux.HandleFunc("/sign-up", func(w http.ResponseWriter, r *http.Request) {
		serveSignUpPage(w, r, homeData)
	})

	// Apply auth middleware to all routes
	handler := auth.AuthMiddleware(authValidator)(mux)

	log.Printf("Starting server on port %s (Auth: %v, Required: %v)", port, enableAuth, requireAuth)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}

// serveHomePage serves the main landing page
// IMPORTANT: This function MUST NOT contain routing logic. All routing belongs to Traefik.
// Services always return relative URLs (/lab1, /lab2, etc.) - Traefik handles routing.
func serveHomePage(w http.ResponseWriter, r *http.Request, data HomePageData, validator *auth.TokenValidator) {
	// Check if services are ready (only in local environment)
	environment := os.Getenv("ENVIRONMENT")
	if environment == "" {
		environment = "local"
	}

	// In local environment, check service health and show custom 404 if critical services not ready
	if environment == "local" && r.URL.Path == "/" {
		log.Printf("🔍 Checking service health for path: %s", r.URL.Path)
		serviceStatuses, allReady, apiAvailable := checkServiceHealth(environment)
		log.Printf("🔍 Health check result: allReady=%v, apiAvailable=%v", allReady, apiAvailable)
		if !allReady || !apiAvailable {
			// Show custom 404 with link to Traefik dashboard
			// If API unavailable, show error message
			log.Printf("⚠️ Services not ready, showing custom 404 page")
			serveStartup404(w, r, serviceStatuses, !apiAvailable)
			return
		}
		log.Printf("✅ All services ready, serving normal home page")
	}

	// Get user info if authenticated
	userInfo := auth.GetUserInfo(r)
	if userInfo != nil {
		data.UserEmail = userInfo.Email
		data.UserID = userInfo.UserID
	}

	// URLs are already relative in data - no need to modify them
	// Traefik handles routing based on path prefixes (/lab1, /lab2, etc.)
	pageData := data

	tmpl := `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E-Skimming Labs - Interactive Training Platform</title>
    <meta name="description" content="Interactive e-skimming attack labs for cybersecurity training and awareness">

    <!-- SEO Meta Tags -->
    <meta name="robots" content="index, follow">
    <meta name="keywords" content="e-skimming, cybersecurity, training, labs, payment security">
    <link rel="canonical" href="{{.Scheme}}://{{.Domain}}/">

    <!-- Open Graph -->
    <meta property="og:title" content="E-Skimming Labs - Interactive Training Platform">
    <meta property="og:description" content="Interactive e-skimming attack labs for cybersecurity training and awareness">
    <meta property="og:url" content="{{.Scheme}}://{{.Domain}}/">
    <meta property="og:type" content="website">

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="E-Skimming Labs - Interactive Training Platform">
    <meta name="twitter:description" content="Interactive e-skimming attack labs for cybersecurity training and awareness">

    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap');

        :root {
            --bg-primary: #0a0e27;
            --bg-secondary: #121733;
            --bg-tertiary: #1a1f3a;
            --bg-card: #1e2440;
            --bg-hover: #252b4a;

            --text-primary: #ffffff;
            --text-secondary: #b8c5db;
            --text-muted: #8b9dc3;

            --accent-red: #ff6b6b;
            --accent-orange: #ff922b;
            --accent-green: #51cf66;
            --accent-blue: #748ffc;
            --accent-purple: #b197fc;
            --accent-pink: #e64980;
            --accent-yellow: #ffd43b;

            --border-color: #2a3f5f;
            --shadow-sm: 0 2px 4px rgba(0,0,0,0.2);
            --shadow-md: 0 4px 12px rgba(0,0,0,0.3);
            --shadow-lg: 0 8px 24px rgba(0,0,0,0.4);

            --gradient-1: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            --gradient-2: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            --gradient-3: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.6;
            overflow-x: hidden;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 20px;
        }

        /* Header */
        .header {
            background: var(--bg-secondary);
            border-bottom: 1px solid var(--border-color);
            padding: 20px 0;
            position: sticky;
            top: 0;
            z-index: 100;
        }

        .header-content {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .logo {
            font-size: 24px;
            font-weight: 700;
            color: var(--accent-blue);
            text-decoration: none;
        }

        .nav-tabs {
            display: flex;
            gap: 20px;
        }

        .nav-tab {
            padding: 10px 20px;
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            color: var(--text-secondary);
            text-decoration: none;
            transition: all 0.3s ease;
            font-weight: 500;
        }

        .nav-tab:hover {
            background: var(--bg-hover);
            color: var(--text-primary);
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }

        .nav-tab.active {
            background: var(--gradient-1);
            color: var(--text-primary);
            border-color: transparent;
        }

        .auth-buttons {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .auth-btn {
            padding: 10px 20px;
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            color: var(--text-secondary);
            cursor: pointer;
            font-weight: 500;
            transition: all 0.3s ease;
            font-family: inherit;
            font-size: 14px;
        }

        .auth-btn:hover {
            background: var(--bg-hover);
            color: var(--text-primary);
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }

        .auth-btn.login-btn {
            background: var(--gradient-1);
            color: var(--text-primary);
            border-color: transparent;
        }

        .auth-btn.logout-btn {
            background: rgba(255, 107, 107, 0.2);
            color: var(--accent-red);
            border-color: var(--accent-red);
        }

        .auth-btn.logout-btn:hover {
            background: rgba(255, 107, 107, 0.3);
        }

        .user-email {
            color: var(--text-secondary);
            font-size: 14px;
            padding: 0 10px;
        }

        /* Hero Section */
        .hero {
            padding: 80px 0;
            text-align: center;
            background: var(--gradient-1);
            margin-bottom: 60px;
        }

        .hero h1 {
            font-size: 48px;
            font-weight: 800;
            margin-bottom: 20px;
            background: linear-gradient(135deg, #fff 0%, #e0e0e0 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .hero p {
            font-size: 20px;
            color: rgba(255, 255, 255, 0.9);
            max-width: 600px;
            margin: 0 auto;
        }

        /* Labs Section */
        .labs-section {
            padding: 60px 0;
        }

        .section-title {
            font-size: 36px;
            font-weight: 700;
            text-align: center;
            margin-bottom: 20px;
            color: var(--text-primary);
        }

        .section-subtitle {
            font-size: 18px;
            color: var(--text-secondary);
            text-align: center;
            margin-bottom: 50px;
            max-width: 600px;
            margin-left: auto;
            margin-right: auto;
        }

        .labs-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 30px;
            margin-bottom: 60px;
        }

        .lab-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 30px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .lab-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: var(--gradient-2);
        }

        .lab-card:hover {
            transform: translateY(-5px);
            box-shadow: var(--shadow-lg);
            border-color: var(--accent-blue);
        }

        .lab-title {
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 15px;
            color: var(--text-primary);
        }

        .lab-description {
            color: var(--text-secondary);
            margin-bottom: 20px;
            line-height: 1.6;
        }

        .lab-meta {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 25px;
        }

        .difficulty {
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }

        .difficulty.beginner {
            background: rgba(81, 207, 102, 0.2);
            color: var(--accent-green);
        }

        .difficulty.intermediate {
            background: rgba(255, 210, 59, 0.2);
            color: var(--accent-yellow);
        }

        .difficulty.advanced {
            background: rgba(255, 107, 107, 0.2);
            color: var(--accent-red);
        }

        .lab-status {
            font-size: 14px;
            color: var(--accent-green);
            font-weight: 500;
        }

        .lab-button {
            display: inline-block;
            padding: 12px 24px;
            background: var(--gradient-1);
            color: var(--text-primary);
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            transition: all 0.3s ease;
            width: 100%;
            text-align: center;
        }

        .lab-button:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }

        /* Resources Section */
        .resources-section {
            padding: 60px 0;
            background: var(--bg-secondary);
            border-radius: 20px;
            margin: 60px 0;
        }

        .resources-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
        }

        .resource-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 30px;
            text-align: center;
            transition: all 0.3s ease;
        }

        .resource-card:hover {
            transform: translateY(-5px);
            box-shadow: var(--shadow-lg);
            border-color: var(--accent-purple);
        }

        .resource-icon {
            font-size: 48px;
            margin-bottom: 20px;
        }

        .resource-title {
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 15px;
            color: var(--text-primary);
        }

        .resource-description {
            color: var(--text-secondary);
            margin-bottom: 25px;
            line-height: 1.6;
        }

        .resource-button {
            display: inline-block;
            padding: 12px 24px;
            background: var(--gradient-3);
            color: var(--text-primary);
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            transition: all 0.3s ease;
        }

        .resource-button:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }

        /* Footer */
        .footer {
            background: var(--bg-secondary);
            border-top: 1px solid var(--border-color);
            padding: 40px 0;
            text-align: center;
            color: var(--text-muted);
        }

        .footer a {
            color: var(--accent-blue);
            text-decoration: none;
        }

        .footer a:hover {
            text-decoration: underline;
        }

        /* Responsive */
        @media (max-width: 768px) {
            .hero h1 {
                font-size: 36px;
            }

            .hero p {
                font-size: 18px;
            }

            .nav-tabs {
                flex-direction: column;
                gap: 10px;
            }

            .labs-grid {
                grid-template-columns: 1fr;
            }

            .resources-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="container">
            <div class="header-content">
                <a href="/" class="logo">E-Skimming Labs</a>
                <nav class="nav-tabs">
                    <a href="/" class="nav-tab active">Home</a>
                    <a href="{{.MITREURL}}" class="nav-tab">MITRE ATT&CK</a>
                    <a href="{{.ThreatModelURL}}" class="nav-tab">Threat Model</a>
                    {{if .AuthEnabled}}
                    <div id="auth-buttons" class="auth-buttons">
                        <button id="login-btn" class="auth-btn login-btn" style="display: none;">Login</button>
                        <button id="logout-btn" class="auth-btn logout-btn" style="display: none;">Logout</button>
                        <span id="user-email" class="user-email" style="display: none;"></span>
                    </div>
                    {{end}}
                </nav>
            </div>
        </div>
    </header>

    <main>
        <section class="hero">
            <div class="container">
                <h1>Interactive E-Skimming Labs</h1>
                <p>Hands-on cybersecurity training for understanding and defending against payment card skimming attacks</p>
            </div>
        </section>

        <section class="labs-section">
            <div class="container">
                <h2 class="section-title">Available Labs</h2>
                <p class="section-subtitle">Choose from our interactive labs designed to teach you about different e-skimming attack techniques and defense strategies.</p>

                <div class="labs-grid">
                    {{range .Labs}}
                    <div class="lab-card">
                        <h3 class="lab-title">{{.Name}}</h3>
                        <p class="lab-description">{{.Description}}</p>
                        <div class="lab-meta">
                            <span class="difficulty {{.Difficulty | lower}}">{{.Difficulty}}</span>
                            <span class="lab-status">{{.Status}}</span>
                        </div>
                        <a href="{{.URL}}" class="lab-button">Start Lab</a>
                    </div>
                    {{end}}
                </div>
            </div>
        </section>

        <section class="resources-section">
            <div class="container">
                <h2 class="section-title">Learning Resources</h2>
                <p class="section-subtitle">Explore our comprehensive resources to deepen your understanding of e-skimming attacks.</p>

                <div class="resources-grid">
                    <div class="resource-card">
                        <div class="resource-icon">🎯</div>
                        <h3 class="resource-title">MITRE ATT&CK Framework</h3>
                        <p class="resource-description">Explore the comprehensive MITRE ATT&CK matrix specifically tailored for e-skimming attacks and payment card fraud.</p>
                        <a href="{{.MITREURL}}" class="resource-button">View ATT&CK Matrix</a>
                    </div>

                    <div class="resource-card">
                        <div class="resource-icon">🔍</div>
                        <h3 class="resource-title">Interactive Threat Model</h3>
                        <p class="resource-description">Visualize attack vectors and understand the threat landscape with our interactive threat modeling tool.</p>
                        <a href="{{.ThreatModelURL}}" class="resource-button">Explore Threat Model</a>
                    </div>
                </div>
            </div>
        </section>
    </main>

    <footer class="footer">
        <div class="container">
            <p>&copy; 2024 E-Skimming Labs. Part of <a href="https://{{.MainDomain}}">PCI Oasis</a> cybersecurity training platform.</p>
        </div>
    </footer>

    {{if .AuthEnabled}}
    <!-- Auth Integration Script -->
    <script src="/static/js/auth.js"></script>
    <script>
        // Initialize auth check (authRequired is always false for home page - it's public)
        if (typeof initLabsAuth === 'function') {
            initLabsAuth({
                authRequired: false,
                mainAppURL: '{{.MainAppURL}}',
                firebaseProjectID: '{{.FirebaseProjectID}}'
            });
        }

        // Update auth buttons based on auth state
        function updateAuthButtons() {
            const loginBtn = document.getElementById('login-btn');
            const logoutBtn = document.getElementById('logout-btn');
            const userEmail = document.getElementById('user-email');

            if (!loginBtn || !logoutBtn) return;

            // Check if user is authenticated
            // Get token from sessionStorage or cookie
            const token = sessionStorage.getItem('firebase_token') || document.cookie.split('; ').find(row => row.startsWith('firebase_token='))?.split('=')[1] || '';
            const headers = {};
            if (token) {
                headers['Authorization'] = 'Bearer ' + token;
            }
            fetch('/api/auth/user', {
                credentials: 'include',
                headers: headers
            })
                .then(response => {
                    if (response.ok) {
                        return response.json();
                    }
                    throw new Error('Not authenticated');
                })
                .then(data => {
                    if (data.authenticated && data.user) {
                        // User is logged in
                        loginBtn.style.display = 'none';
                        logoutBtn.style.display = 'block';
                        if (userEmail) {
                            userEmail.textContent = data.user.email;
                            userEmail.style.display = 'inline';
                        }
                    } else {
                        // User is not logged in
                        loginBtn.style.display = 'block';
                        logoutBtn.style.display = 'none';
                        if (userEmail) {
                            userEmail.style.display = 'none';
                        }
                    }
                })
                .catch(() => {
                    // Not authenticated
                    loginBtn.style.display = 'block';
                    logoutBtn.style.display = 'none';
                    if (userEmail) {
                        userEmail.style.display = 'none';
                    }
                });
        }

        // Login button handler
        document.addEventListener('DOMContentLoaded', function() {
            updateAuthButtons();

            const loginBtn = document.getElementById('login-btn');
            const logoutBtn = document.getElementById('logout-btn');

            if (loginBtn) {
                loginBtn.addEventListener('click', function() {
                    const redirectUrl = encodeURIComponent(window.location.href);
                    // IMPORTANT: Always use relative URL - Traefik handles routing
                    // MainAppURL is empty, so this becomes /sign-in?redirect=...
                    window.location.href = '{{.MainAppURL}}/sign-in?redirect=' + redirectUrl;
                });
            }

            if (logoutBtn) {
                logoutBtn.addEventListener('click', function() {
                    sessionStorage.removeItem('firebase_token');
                    // Clear cookie
                    document.cookie = 'firebase_token=; path=/; max-age=0';
                    updateAuthButtons();
                    // Reload to clear any protected content
                    window.location.reload();
                });
            }
        });
    </script>
    {{end}}

    <script>
        // Add smooth scrolling for anchor links
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                document.querySelector(this.getAttribute('href')).scrollIntoView({
                    behavior: 'smooth'
                });
            });
        });

        // Add loading states for lab buttons
        document.querySelectorAll('.lab-button').forEach(button => {
            button.addEventListener('click', function(e) {
                this.textContent = 'Loading...';
                this.style.opacity = '0.7';
            });
        });
    </script>
</body>
</html>`

	t, err := template.New("home").Funcs(template.FuncMap{
		"lower": strings.ToLower,
	}).Parse(tmpl)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	err = t.Execute(w, pageData)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

func serveMITREPage(w http.ResponseWriter, r *http.Request, homeData HomePageData, validator *auth.TokenValidator) {
	// Try multiple paths for local development and container environments
	paths := []string{
		"/app/docs/mitre-attack-visual.html",        // Container path
		"../../docs/mitre-attack-visual.html",        // Local dev from service directory
		"docs/mitre-attack-visual.html",              // Local dev from root
		"../docs/mitre-attack-visual.html",           // Alternative local path
	}

	var mitreHTML []byte
	var err error

	for _, path := range paths {
		mitreHTML, err = os.ReadFile(path)
		if err == nil {
			log.Printf("Served MITRE ATT&CK page from: %s", path)
			break
		}
	}

	if err != nil {
		log.Printf("Failed to read MITRE ATT&CK page from all paths: %v", err)
		http.Error(w, "MITRE ATT&CK page not found", http.StatusNotFound)
		return
	}

	// Get user info if authenticated
	userInfo := auth.GetUserInfo(r)
	if userInfo != nil {
		homeData.UserEmail = userInfo.Email
		homeData.UserID = userInfo.UserID
	}

	// Inject auth buttons into the HTML (MITRE ATT&CK is public, so authRequired=false)
	htmlStr := string(mitreHTML)
	htmlStr = injectAuthButtons(htmlStr, homeData, false)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(htmlStr))
}

func serveThreatModelPage(w http.ResponseWriter, r *http.Request, homeData HomePageData, validator *auth.TokenValidator) {
	// Try multiple paths for local development and container environments
	paths := []string{
		"/app/docs/interactive-threat-model.html",        // Container path
		"../../docs/interactive-threat-model.html",        // Local dev from service directory
		"docs/interactive-threat-model.html",              // Local dev from root
		"../docs/interactive-threat-model.html",           // Alternative local path
	}

	var threatModelHTML []byte
	var err error

	for _, path := range paths {
		threatModelHTML, err = os.ReadFile(path)
		if err == nil {
			log.Printf("Served Threat Model page from: %s", path)
			break
		}
	}

	if err != nil {
		log.Printf("Failed to read Threat Model page from all paths: %v", err)
		http.Error(w, "Threat model page not found", http.StatusNotFound)
		return
	}

	// Get user info if authenticated
	userInfo := auth.GetUserInfo(r)
	if userInfo != nil {
		homeData.UserEmail = userInfo.Email
		homeData.UserID = userInfo.UserID
	}

	// Inject auth buttons into the HTML (Threat Model is public, so authRequired=false)
	htmlStr := string(threatModelHTML)
	htmlStr = injectAuthButtons(htmlStr, homeData, false)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(htmlStr))
}

// serveDocsFile serves static files from the docs directory
func serveDocsFile(w http.ResponseWriter, r *http.Request, filename string) {
	// Try multiple paths for local development and container environments
	paths := []string{
		fmt.Sprintf("/app/docs/%s", filename),        // Container path
		fmt.Sprintf("../../docs/%s", filename),        // Local dev from service directory
		fmt.Sprintf("docs/%s", filename),              // Local dev from root
		fmt.Sprintf("../docs/%s", filename),           // Alternative local path
	}

	var fileContent []byte
	var err error

	for _, path := range paths {
		fileContent, err = os.ReadFile(path)
		if err == nil {
			log.Printf("Served %s from: %s", filename, path)
			break
		}
	}

	if err != nil {
		log.Printf("Failed to read %s from all paths: %v", filename, err)
		http.Error(w, fmt.Sprintf("File not found: %s", filename), http.StatusNotFound)
		return
	}

	// Set appropriate Content-Type based on file extension
	contentType := "application/octet-stream"
	if strings.HasSuffix(filename, ".js") {
		contentType = "application/javascript"
	} else if strings.HasSuffix(filename, ".css") {
		contentType = "text/css"
	} else if strings.HasSuffix(filename, ".json") {
		contentType = "application/json"
	}

	w.Header().Set("Content-Type", contentType)
	w.Write(fileContent)
}

func serveLabWriteup(w http.ResponseWriter, r *http.Request, labID string, homeData HomePageData, validator *auth.TokenValidator) {
	// Read the README file for the lab
	// In container: /app/docs/labs/{lab-id}/README.md (copied from labs/{lab-id}/README.md)
	// Local dev: labs/{lab-id}/README.md (original location, no duplication)
	// Lab IDs should match folder names: 01-basic-magecart, 02-dom-skimming, 03-extension-hijacking

	readmePath := fmt.Sprintf("/app/docs/labs/%s/README.md", labID)

	// Log for debugging
	log.Printf("Attempting to read writeup for lab: %s", labID)
	log.Printf("Trying container path: %s", readmePath)

	readmeContent, err := os.ReadFile(readmePath)
	if err != nil {
		log.Printf("Failed to read %s: %v", readmePath, err)

		// Try local development path (original location, no duplication)
		localPath := fmt.Sprintf("labs/%s/README.md", labID)
		log.Printf("Trying local development path: %s", localPath)
		readmeContent, err = os.ReadFile(localPath)
		if err != nil {
			log.Printf("Failed to read %s: %v", localPath, err)

			// List what's actually in /app/docs for debugging
			if entries, listErr := os.ReadDir("/app/docs"); listErr == nil {
				var names []string
				for _, e := range entries {
					names = append(names, e.Name())
				}
				log.Printf("Contents of /app/docs: %v", names)
			}

			http.Error(w, fmt.Sprintf("Lab writeup not found: %s\n\nTried paths:\n- %s (container)\n- %s (local dev)\n\nCheck container logs for details.", labID, readmePath, localPath), http.StatusNotFound)
			return
		}
		log.Printf("Successfully read from local development path: %s", localPath)
	} else {
		log.Printf("Successfully read from container path: %s", readmePath)
	}

	// Convert markdown to HTML server-side
	md := []byte(readmeContent)
	htmlFlags := html.CommonFlags | html.HrefTargetBlank
	opts := html.RendererOptions{Flags: htmlFlags}
	renderer := html.NewRenderer(opts)
	htmlContent := markdown.ToHTML(md, nil, renderer)

	// Highlight attack lines in code blocks
	htmlContent = highlightAttackLines(htmlContent)

	// Determine lab URL for "Back to Lab" button
	// Always use relative URLs - Traefik handles routing
	var labBackURL string
	switch labID {
	case "01-basic-magecart":
		labBackURL = "/lab1"
	case "02-dom-skimming":
		labBackURL = "/lab2"
	case "03-extension-hijacking":
		labBackURL = "/lab3"
	default:
		labBackURL = "/" // Fallback to home
	}

	// Get user info if authenticated
	userInfo := auth.GetUserInfo(r)
	if userInfo != nil {
		homeData.UserEmail = userInfo.Email
		homeData.UserID = userInfo.UserID
	}

	// Build auth buttons HTML if enabled
	authButtonsHTML := ""
	if homeData.AuthEnabled {
		authButtonsHTML = `
            <div id="auth-buttons" class="auth-buttons" style="display: flex; align-items: center; gap: 10px; margin-left: auto;">
                <button id="login-btn" class="auth-btn login-btn" style="display: none; padding: 8px 16px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: 500;">Login</button>
                <button id="logout-btn" class="auth-btn logout-btn" style="display: none; padding: 8px 16px; background: rgba(255, 107, 107, 0.2); color: #ff6b6b; border: 1px solid #ff6b6b; border-radius: 4px; cursor: pointer; font-weight: 500;">Logout</button>
                <span id="user-email" class="user-email" style="display: none; color: white; font-size: 14px; padding: 0 10px;"></span>
            </div>`
	}

	// Build auth scripts if enabled
	authScripts := ""
	if homeData.AuthEnabled {
		authScripts = fmt.Sprintf(`
		<script src="/static/js/auth.js"></script>
		<script>
			// Initialize auth check
			if (typeof initLabsAuth === 'function') {
				initLabsAuth({
					authRequired: %t,
					mainAppURL: '%s',
					firebaseProjectID: '%s'
				});
			}

			// Update auth buttons based on auth state
			function updateAuthButtons() {
				const loginBtn = document.getElementById('login-btn');
				const logoutBtn = document.getElementById('logout-btn');
				const userEmail = document.getElementById('user-email');

				if (!loginBtn || !logoutBtn) return;

				// Check if user is authenticated
				// Get token from sessionStorage or cookie
				const token = sessionStorage.getItem('firebase_token') || document.cookie.split('; ').find(row => row.startsWith('firebase_token='))?.split('=')[1] || '';
				const headers = {};
				if (token) {
					headers['Authorization'] = 'Bearer ' + token;
				}
				fetch('/api/auth/user', {
					credentials: 'include',
					headers: headers
				})
					.then(response => {
						if (response.ok) {
							return response.json();
						}
						throw new Error('Not authenticated');
					})
					.then(data => {
						if (data.authenticated && data.user) {
							// User is logged in
							loginBtn.style.display = 'none';
							logoutBtn.style.display = 'block';
							if (userEmail) {
								userEmail.textContent = data.user.email;
								userEmail.style.display = 'inline';
							}
						} else {
							// User is not logged in
							loginBtn.style.display = 'block';
							logoutBtn.style.display = 'none';
							if (userEmail) {
								userEmail.style.display = 'none';
							}
						}
					})
					.catch(() => {
						// Not authenticated
						loginBtn.style.display = 'block';
						logoutBtn.style.display = 'none';
						if (userEmail) {
							userEmail.style.display = 'none';
						}
					});
			}

			// Login button handler
			document.addEventListener('DOMContentLoaded', function() {
				updateAuthButtons();

				const loginBtn = document.getElementById('login-btn');
				const logoutBtn = document.getElementById('logout-btn');

				if (loginBtn) {
					loginBtn.addEventListener('click', function() {
						const redirectUrl = encodeURIComponent(window.location.href);
						window.location.href = '%s/sign-in?redirect=' + redirectUrl;
					});
				}

				if (logoutBtn) {
					logoutBtn.addEventListener('click', function() {
						sessionStorage.removeItem('firebase_token');
						updateAuthButtons();
						// Reload to clear any protected content
						window.location.reload();
					});
				}
			});
		</script>
		`, homeData.AuthRequired, homeData.MainAppURL, homeData.FirebaseProjectID, homeData.MainAppURL)
	}

	// Create HTML page
	html := fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lab Writeup - %s</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            color: white;
            padding: 2rem;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .header h1 {
            font-size: 2rem;
            margin-bottom: 0.5rem;
        }
        .nav {
            margin-top: 1rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .nav > div {
            display: flex;
            gap: 1rem;
        }
        .nav a {
            color: white;
            text-decoration: none;
            margin-right: 1rem;
            padding: 0.5rem 1rem;
            background: rgba(255,255,255,0.2);
            border-radius: 4px;
            display: inline-block;
        }
        .nav a:hover {
            background: rgba(255,255,255,0.3);
        }
        .container {
            max-width: 900px;
            margin: 0 auto;
            padding: 2rem;
            background: white;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-top: 2rem;
            margin-bottom: 2rem;
            border-radius: 8px;
        }
        .markdown-content {
            line-height: 1.8;
        }
        .markdown-content h1 { font-size: 2rem; margin: 1.5rem 0 1rem; color: #333; }
        .markdown-content h2 { font-size: 1.5rem; margin: 1.5rem 0 1rem; color: #555; border-bottom: 2px solid #667eea; padding-bottom: 0.5rem; }
        .markdown-content h3 { font-size: 1.25rem; margin: 1.25rem 0 0.75rem; color: #666; }
        .markdown-content h4 { font-size: 1.1rem; margin: 1rem 0 0.5rem; color: #777; }
        .markdown-content p { margin: 1rem 0; }
        .markdown-content ul, .markdown-content ol { margin: 1rem 0; padding-left: 2rem; }
        .markdown-content li { margin: 0.5rem 0; }
        .markdown-content code {
            background: #f4f4f4;
            padding: 0.2rem 0.4rem;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
        }
        .markdown-content pre {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 1rem;
            border-radius: 4px;
            overflow-x: auto;
            margin: 1rem 0;
            position: relative;
        }
        .markdown-content pre code {
            background: none;
            padding: 0;
            color: inherit;
        }
        .markdown-content pre code.hljs {
            padding: 0;
        }
        .markdown-content pre .attack-line {
            background: rgba(255, 107, 107, 0.3);
            border-left: 4px solid #ff6b6b;
            padding-left: 0.5rem;
            margin-left: -0.5rem;
            display: block;
        }
        .markdown-content pre .attack-line::before {
            content: "⚠️";
            margin-right: 0.5rem;
            color: #ff6b6b;
        }
        .markdown-content blockquote {
            border-left: 4px solid #667eea;
            padding-left: 1rem;
            margin: 1rem 0;
            color: #666;
            font-style: italic;
        }
        .markdown-content table {
            width: 100%%;
            border-collapse: collapse;
            margin: 1rem 0;
        }
        .markdown-content th, .markdown-content td {
            border: 1px solid #ddd;
            padding: 0.75rem;
            text-align: left;
        }
        .markdown-content th {
            background: #667eea;
            color: white;
        }
        .markdown-content tr:nth-child(even) {
            background: #f9f9f9;
        }
        .markdown-content a {
            color: #667eea;
            text-decoration: none;
        }
        .markdown-content a:hover {
            text-decoration: underline;
        }
        .markdown-content strong {
            color: #333;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Lab Writeup</h1>
        <div class="nav" style="display: flex; align-items: center; justify-content: space-between;">
            <div>
                <a href="/">🏠 Home</a>
                <a href="%s">← Back to Lab</a>
                <a href="%s">MITRE ATT&CK</a>
                <a href="%s">Threat Model</a>
            </div>
            %s
        </div>
    </div>
    <div class="container">
        <div class="markdown-content">%s</div>
    </div>
    %s
    <script>
        // Highlight code blocks
        document.querySelectorAll('pre code').forEach((block) => {
            hljs.highlightElement(block);
        });
    </script>
</body>
</html>`, labID, labBackURL, homeData.MITREURL, homeData.ThreatModelURL, authButtonsHTML, template.HTML(htmlContent), authScripts)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(html))
}

// highlightAttackLines highlights lines in code blocks that contain attack patterns
func highlightAttackLines(htmlContent []byte) []byte {
	htmlStr := string(htmlContent)

	// Pattern to match code blocks
	codeBlockPattern := regexp.MustCompile(`<pre><code[^>]*>([\s\S]*?)</code></pre>`)

	htmlStr = codeBlockPattern.ReplaceAllStringFunc(htmlStr, func(match string) string {
		// Extract the code content
		codeMatch := regexp.MustCompile(`<pre><code[^>]*>([\s\S]*?)</code></pre>`)
		submatches := codeMatch.FindStringSubmatch(match)
		if len(submatches) < 2 {
			return match
		}

		codeContent := submatches[1]
		lines := strings.Split(codeContent, "\n")

		// Attack line patterns
		attackPatterns := []*regexp.Regexp{
			regexp.MustCompile(`exfilUrl|exfiltrate`),
			regexp.MustCompile(`\bC2\b|collect`),
			regexp.MustCompile(`MALICIOUS|skimmer`),
			regexp.MustCompile(`addEventListener.*(?:submit|input)`),
			regexp.MustCompile(`MutationObserver|shadowRoot`),
			regexp.MustCompile(`chrome\.runtime|sendMessage`),
			regexp.MustCompile(`/collect|/exfil|localhost:90\d{2}`),
		}

		highlightedLines := make([]string, len(lines))
		for i, line := range lines {
			isAttackLine := false
			for _, pattern := range attackPatterns {
				if pattern.MatchString(line) {
					isAttackLine = true
					break
				}
			}

			if isAttackLine && strings.TrimSpace(line) != "" {
				// Escape HTML in the line first, then wrap it
				escapedLine := template.HTMLEscapeString(line)
				highlightedLines[i] = `<span class="attack-line">` + escapedLine + `</span>`
			} else {
				highlightedLines[i] = line
			}
		}

		// Reconstruct the code block
		newCodeContent := strings.Join(highlightedLines, "\n")
		return strings.Replace(match, codeContent, newCodeContent, 1)
	})

	return []byte(htmlStr)
}

// serveAuthValidate validates a Firebase token
func serveAuthValidate(w http.ResponseWriter, r *http.Request, validator *auth.TokenValidator) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Token string `json:"token"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	userInfo, err := validator.ValidateToken(r.Context(), req.Token)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"valid": false,
			"error": err.Error(),
		})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"valid": true,
		"user": map[string]interface{}{
			"id":            userInfo.UserID,
			"email":         userInfo.Email,
			"emailVerified": userInfo.EmailVerified,
		},
	})
}

// serveAuthSignInURL returns the sign-in URL for the main app
// IMPORTANT: This function MUST NOT contain routing logic. All routing belongs to Traefik.
// Always uses relative URLs (/sign-in) - Traefik handles routing.
func serveAuthSignInURL(w http.ResponseWriter, r *http.Request, homeData HomePageData) {
	redirectParam := r.URL.Query().Get("redirect")
	// Always use relative path - Traefik routes /sign-in to the appropriate service
	signInURL := fmt.Sprintf("/sign-in?redirect=%s", redirectParam)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"signInUrl": signInURL,
	})
}

// serveAuthUser returns current user information if authenticated
// This endpoint is public (bypasses auth middleware) but validates token to return user info
func serveAuthUser(w http.ResponseWriter, r *http.Request, validator *auth.TokenValidator) {
	// First try to get user info from context (if request went through auth middleware)
	userInfo := auth.GetUserInfo(r)

	// If not in context, extract and validate token directly (for public endpoint)
	if userInfo == nil {
		// Extract token from request
		token := extractTokenFromRequest(r)
		if token == "" {
			// Log for debugging
			log.Printf("🔍 /api/auth/user - No token found (cookies: %v)", r.Cookies())
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"authenticated": false,
			})
			return
		}

		// Log token for debugging (sanitized)
		log.Printf("🔍 /api/auth/user - Token found: %s", sanitizeToken(token))

		// Validate token
		var err error
		userInfo, err = validator.ValidateToken(r.Context(), token)
		if err != nil || userInfo == nil {
			log.Printf("❌ /api/auth/user - Token validation failed: %v", err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"authenticated": false,
			})
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"authenticated": true,
		"user": map[string]interface{}{
			"id":            userInfo.UserID,
			"email":         userInfo.Email,
			"emailVerified": userInfo.EmailVerified,
		},
	})
}

// extractTokenFromRequest extracts token from Authorization header, cookie, or query parameter
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

// injectAuthButtons injects auth buttons and scripts into HTML pages
// authRequired indicates whether the page requires authentication (false for public pages like home, mitre-attack, threat-model)
func injectAuthButtons(html string, homeData HomePageData, authRequired bool) string {
	if !homeData.AuthEnabled {
		return html
	}

	// Create auth buttons HTML
	authButtonsHTML := fmt.Sprintf(`
		<div id="auth-buttons" class="auth-buttons" style="display: flex; align-items: center; gap: 10px; margin-left: 20px;">
			<button id="login-btn" class="auth-btn login-btn" style="display: none; padding: 10px 20px; background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); color: white; border: none; border-radius: 8px; cursor: pointer; font-weight: 500; transition: all 0.3s ease;">Login</button>
			<button id="logout-btn" class="auth-btn logout-btn" style="display: none; padding: 10px 20px; background: rgba(255, 107, 107, 0.2); color: #ff6b6b; border: 1px solid #ff6b6b; border-radius: 8px; cursor: pointer; font-weight: 500; transition: all 0.3s ease;">Logout</button>
			<span id="user-email" class="user-email" style="display: none; color: #b8c5db; font-size: 14px; padding: 0 10px;"></span>
		</div>
	`)

	// Create auth scripts
	authScripts := fmt.Sprintf(`
		<script src="/static/js/auth.js"></script>
		<script>
			// Initialize auth check
			if (typeof initLabsAuth === 'function') {
				initLabsAuth({
					authRequired: %t,
					mainAppURL: '%s',
					firebaseProjectID: '%s'
				});
			}

			// Update auth buttons based on auth state
			function updateAuthButtons() {
				const loginBtn = document.getElementById('login-btn');
				const logoutBtn = document.getElementById('logout-btn');
				const userEmail = document.getElementById('user-email');

				if (!loginBtn || !logoutBtn) return;

				// Check if user is authenticated
				// Get token from sessionStorage or cookie
				const token = sessionStorage.getItem('firebase_token') || document.cookie.split('; ').find(row => row.startsWith('firebase_token='))?.split('=')[1] || '';
				const headers = {};
				if (token) {
					headers['Authorization'] = 'Bearer ' + token;
				}
				fetch('/api/auth/user', {
					credentials: 'include',
					headers: headers
				})
					.then(response => {
						if (response.ok) {
							return response.json();
						}
						throw new Error('Not authenticated');
					})
					.then(data => {
						if (data.authenticated && data.user) {
							// User is logged in
							loginBtn.style.display = 'none';
							logoutBtn.style.display = 'block';
							if (userEmail) {
								userEmail.textContent = data.user.email;
								userEmail.style.display = 'inline';
							}
						} else {
							// User is not logged in
							loginBtn.style.display = 'block';
							logoutBtn.style.display = 'none';
							if (userEmail) {
								userEmail.style.display = 'none';
							}
						}
					})
					.catch(() => {
						// Not authenticated
						loginBtn.style.display = 'block';
						logoutBtn.style.display = 'none';
						if (userEmail) {
							userEmail.style.display = 'none';
						}
					});
			}

			// Login button handler
			document.addEventListener('DOMContentLoaded', function() {
				updateAuthButtons();

				const loginBtn = document.getElementById('login-btn');
				const logoutBtn = document.getElementById('logout-btn');

				if (loginBtn) {
					loginBtn.addEventListener('click', function() {
						const redirectUrl = encodeURIComponent(window.location.href);
						window.location.href = '%s/sign-in?redirect=' + redirectUrl;
					});
				}

				if (logoutBtn) {
					logoutBtn.addEventListener('click', function() {
						sessionStorage.removeItem('firebase_token');
						updateAuthButtons();
						// Reload to clear any protected content
						window.location.reload();
					});
				}
			});
		</script>
	`, authRequired, homeData.MainAppURL, homeData.FirebaseProjectID, homeData.MainAppURL)

	// Try to inject buttons into header/nav elements
	// Look for common header patterns
	patterns := []struct {
		find    string
		replace string
		description string
	}{
		{
			// Pattern 1: MITRE page - inject into header-top div
			find:    `<div class="header-top">`,
			replace: `<div class="header-top" style="display: flex; justify-content: space-between; align-items: center;">` + authButtonsHTML,
			description: "MITRE header-top",
		},
		{
			// Pattern 2: Threat model - inject into flex container with back button
			find:    `<div style="display: flex; align-items: center; gap: 20px; margin-top: 10px">`,
			replace: `<div style="display: flex; align-items: center; gap: 20px; margin-top: 10px; justify-content: space-between;">` + authButtonsHTML,
			description: "Threat model flex container",
		},
		{
			// Pattern 2b: Threat model fallback - inject after h1
			find:    `</h1>`,
			replace: `</h1>` + authButtonsHTML,
			description: "Threat model h1 fallback",
		},
		{
			// Pattern 3: Look for </nav> and inject before it
			find:    `</nav>`,
			replace: authButtonsHTML + `</nav>`,
			description: "nav closing tag",
		},
		{
			// Pattern 4: Look for header closing tag
			find:    `</header>`,
			replace: authButtonsHTML + `</header>`,
			description: "header closing tag",
		},
		{
			// Pattern 5: Look for navigation container
			find:    `<div class="nav">`,
			replace: `<div class="nav">` + authButtonsHTML,
			description: "nav div",
		},
	}

	injected := false
	for _, pattern := range patterns {
		if strings.Contains(html, pattern.find) {
			html = strings.Replace(html, pattern.find, pattern.replace, 1)
			log.Printf("✅ Injected auth buttons using pattern: %s", pattern.description)
			injected = true
			break
		}
	}

	if !injected {
		log.Printf("⚠️ Could not find injection point for auth buttons")
	}

	// Inject scripts before </body>
	if strings.Contains(html, "</body>") {
		html = strings.Replace(html, "</body>", authScripts+"</body>", 1)
	} else if strings.Contains(html, "</html>") {
		html = strings.Replace(html, "</html>", authScripts+"</html>", 1)
	}

	return html
}

// serveAuthJS serves the client-side Firebase Auth integration script
func serveAuthJS(w http.ResponseWriter, r *http.Request, homeData HomePageData) {
	if !homeData.AuthEnabled {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	script := `// E-Skimming Labs Auth Integration
(function() {
    'use strict';

    // Check for token in URL (legacy support - new flow uses cookies directly)
    // If token is in URL, extract it and store in cookie, then remove from URL
    const urlParams = new URLSearchParams(window.location.search);
    const token = urlParams.get('token');

    if (token) {
        // Store token in both sessionStorage (for client-side) and cookie (for server-side)
        sessionStorage.setItem('firebase_token', token);
        // Set cookie that will be sent with all requests
        // Cookie expires in 1 hour (3600 seconds)
        // Use SameSite=None; Secure for HTTPS (allows cross-site), SameSite=Lax for HTTP (local dev)
        const isSecure = window.location.protocol === 'https:';
        const sameSiteAttr = isSecure ? 'SameSite=None; Secure' : 'SameSite=Lax';
        document.cookie = 'firebase_token=' + encodeURIComponent(token) + '; path=/; max-age=3600; ' + sameSiteAttr;
        // Remove token from URL for security
        const newUrl = window.location.pathname + (window.location.search.replace(/[?&]token=[^&]*/, '').replace(/^&/, '?') || '');
        window.history.replaceState({}, '', newUrl);
        console.log('✅ Token extracted from URL and stored in cookie (legacy flow)');
    }

    // Function to initialize auth - prevent multiple initializations
    let authInitialized = false;
    window.initLabsAuth = function(config) {
        // Prevent multiple initializations
        if (authInitialized) {
            console.log('⚠️ Auth already initialized, skipping duplicate call');
            return;
        }
        authInitialized = true;

        const { authRequired, mainAppURL, firebaseProjectID } = config;

        // Check for token in sessionStorage
        const storedToken = sessionStorage.getItem('firebase_token');

        if (storedToken) {
            // Validate token with server (only once)
            fetch('/api/auth/validate', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ' + storedToken
                },
                body: JSON.stringify({ token: storedToken })
            })
            .then(response => {
                if (response.ok) {
                    console.log('✅ Authentication validated');
                    return response.json();
                } else {
                    // Token invalid, clear it
                    sessionStorage.removeItem('firebase_token');
                    // Clear cookie
                    document.cookie = 'firebase_token=; path=/; max-age=0';
                    if (authRequired) {
                        redirectToSignIn(mainAppURL);
                    }
                    throw new Error('Token validation failed');
                }
            })
            .catch(error => {
                console.error('Auth validation error:', error);
                if (authRequired) {
                    redirectToSignIn(mainAppURL);
                }
            });
        } else {
            // No token found
            if (authRequired) {
                redirectToSignIn(mainAppURL);
            }
        }

        // Listen for postMessage from main app (for SSO)
        window.addEventListener('message', function(event) {
            // Verify origin matches main app domain
            const mainAppOrigin = mainAppURL.replace(/^https?:\/\//, '');
            if (!event.origin.includes(mainAppOrigin.split('/')[0])) {
                return;
            }

            if (event.data && event.data.type === 'FIREBASE_TOKEN' && event.data.token) {
                sessionStorage.setItem('firebase_token', event.data.token);
                // Validate the token
                fetch('/api/auth/validate', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ' + event.data.token
                    },
                    body: JSON.stringify({ token: event.data.token })
                })
                .then(response => {
                    if (response.ok) {
                        console.log('✅ SSO token validated');
                        // Reload to apply auth state
                        window.location.reload();
                    }
                })
                .catch(error => {
                    console.error('SSO token validation error:', error);
                });
            }
        });

        // Request token from parent window (if in iframe) or opener (if opened from main app)
        if (window.parent !== window) {
            window.parent.postMessage({ type: 'REQUEST_FIREBASE_TOKEN' }, '*');
        }
    };

    function redirectToSignIn(mainAppURL) {
        const redirectUrl = encodeURIComponent(window.location.href);
        window.location.href = mainAppURL + '/sign-in?redirect=' + redirectUrl;
    }
})();`

	w.Header().Set("Content-Type", "application/javascript")
	w.Write([]byte(script))
}

// serveAuthCheckJS serves a simple auth check script
func serveAuthCheckJS(w http.ResponseWriter, r *http.Request) {
	script := `
// Simple auth check
(async function() {
    try {
        // Get token from sessionStorage or cookie
        const token = sessionStorage.getItem('firebase_token') || document.cookie.split('; ').find(row => row.startsWith('firebase_token='))?.split('=')[1] || '';
        const headers = {};
        if (token) {
            headers['Authorization'] = 'Bearer ' + token;
        }
        const response = await fetch('/api/auth/user', {
            credentials: 'include',
            headers: headers
        });
        const data = await response.json();
        if (data.authenticated) {
            console.log('✅ User authenticated:', data.user.email);
        }
    } catch (error) {
        console.error('Auth check error:', error);
    }
})();
`
	w.Header().Set("Content-Type", "application/javascript")
	w.Write([]byte(script))
}

func serveLabsAPI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Get labs data with detailed descriptions
	labs := []Lab{
		{
			ID:          "lab1-basic-magecart",
			Name:        "Basic Magecart Attack",
			Description: "Learn the fundamentals of payment card skimming attacks through JavaScript injection. Understand how attackers compromise e-commerce sites, intercept form submissions, and exfiltrate credit card data. Practice detection using browser DevTools and implement basic defensive measures.",
			Difficulty:  "Beginner",
			URL:         "/lab1-basic-magecart",
			Status:      "Available",
		},
		{
			ID:          "lab2-dom-skimming",
			Name:        "DOM-Based Skimming",
			Description: "Master advanced DOM manipulation techniques for stealthy payment data capture. Learn real-time field monitoring, dynamic form injection, Shadow DOM abuse, and DOM tree manipulation. Understand how attackers bypass traditional detection methods.",
			Difficulty:  "Intermediate",
			URL:         "/lab2-dom-skimming",
			Status:      "Available",
		},
		{
			ID:          "lab3-extension-hijacking",
			Name:        "Browser Extension Hijacking",
			Description: "Explore sophisticated browser extension-based attacks that exploit privileged APIs and persistent access. Learn about content script injection, background script persistence, cross-origin communication, and supply chain attacks through malicious extensions.",
			Difficulty:  "Advanced",
			URL:         "/lab3-extension-hijacking",
			Status:      "Available",
		},
	}

	json.NewEncoder(w).Encode(labs)
}

// serveSignInPage serves the sign-in page with Firebase Authentication
func serveSignInPage(w http.ResponseWriter, r *http.Request, homeData HomePageData) {
	// Log sign-in page access with client details
	clientIP := r.Header.Get("X-Forwarded-For")
	if clientIP == "" {
		clientIP = r.RemoteAddr
	}
	userAgent := r.Header.Get("User-Agent")
	errorParam := r.URL.Query().Get("error")
	emailParam := r.URL.Query().Get("email")

	if errorParam != "" {
		log.Printf("🔐 Sign-in page accessed with error [ip=%s, error=%s, email=%s, user-agent=%s]",
			sanitizeForLog(clientIP, 50), sanitizeForLog(errorParam, 100), sanitizeForLog(emailParam, 100), sanitizeForLog(userAgent, 100))
	} else {
		log.Printf("🔐 Sign-in page accessed [ip=%s, user-agent=%s]", sanitizeForLog(clientIP, 50), sanitizeForLog(userAgent, 100))
	}

	if !homeData.AuthEnabled {
		log.Printf("❌ Sign-in attempted but authentication is disabled [ip=%s]", clientIP)
		http.Error(w, "Authentication is not enabled", http.StatusNotFound)
		return
	}

	// Get redirect URL from query parameter
	redirectURL := r.URL.Query().Get("redirect")
	if redirectURL == "" {
		redirectURL = "/"
	}

	log.Printf("🔐 Sign-in page rendered [ip=%s, redirect=%s]", sanitizeForLog(clientIP, 50), sanitizeForLog(redirectURL, 200))

	// Get Firebase config from environment
	firebaseAPIKey := os.Getenv("FIREBASE_API_KEY")
	firebaseAuthDomain := os.Getenv("FIREBASE_AUTH_DOMAIN")
	if firebaseAuthDomain == "" && homeData.FirebaseProjectID != "" {
		firebaseAuthDomain = fmt.Sprintf("%s.firebaseapp.com", homeData.FirebaseProjectID)
	}

	html := fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Cross-Origin-Opener-Policy" content="same-origin-allow-popups">
    <meta http-equiv="Cross-Origin-Embedder-Policy" content="unsafe-none">
    <title>Sign In - E-Skimming Labs</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .signin-container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 400px;
            width: 100%%;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 28px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            color: #333;
            font-weight: 500;
            font-size: 14px;
        }
        input {
            width: 100%%;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 6px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%%;
            padding: 12px;
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 10px;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }
        .error {
            color: #e74c3c;
            font-size: 14px;
            margin-top: 10px;
            display: none;
        }
        .error.show {
            display: block;
        }
        .divider {
            text-align: center;
            margin: 20px 0;
            color: #999;
            font-size: 14px;
            position: relative;
        }
        .divider::before,
        .divider::after {
            content: '';
            position: absolute;
            top: 50%%;
            width: 40%%;
            height: 1px;
            background: #ddd;
        }
        .divider::before {
            left: 0;
        }
        .divider::after {
            right: 0;
        }
        .google-btn {
            background: white;
            color: #333;
            border: 1px solid #ddd;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
        }
        .google-btn:hover {
            background: #f5f5f5;
        }
        .signup-link {
            text-align: center;
            margin-top: 20px;
            font-size: 14px;
            color: #666;
        }
        .signup-link a {
            color: #667eea;
            text-decoration: none;
            font-weight: 500;
        }
        .signup-link a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="signin-container">
        <h1>Sign In</h1>
        <p class="subtitle">Access E-Skimming Labs</p>

        <form id="signin-form">
            <div class="form-group">
                <label for="email">Email</label>
                <input type="email" id="email" name="email" required autocomplete="email">
            </div>
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" name="password" required autocomplete="current-password">
            </div>
            <div class="error" id="error"></div>
            <button type="submit" id="submit-btn">Sign In</button>
        </form>

        <div class="divider">or</div>

        <button class="google-btn" id="google-btn">
            <svg width="18" height="18" viewBox="0 0 18 18">
                <path fill="#4285F4" d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.874 2.684-6.615z"/>
                <path fill="#34A853" d="M9 18c2.43 0 4.467-.806 5.96-2.184l-2.908-2.258c-.806.54-1.837.86-3.052.86-2.347 0-4.337-1.584-5.046-3.711H.957v2.332C2.438 15.983 5.482 18 9 18z"/>
                <path fill="#FBBC05" d="M3.954 10.707c-.18-.54-.282-1.117-.282-1.707s.102-1.167.282-1.707V4.961H.957C.348 6.175 0 7.55 0 9s.348 2.825.957 4.039l3.997-3.332z"/>
                <path fill="#EA4335" d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0 5.482 0 2.438 2.017.957 4.961L3.954 7.293C4.663 5.163 6.653 3.58 9 3.58z"/>
            </svg>
            Sign in with Google
        </button>

        <div class="signup-link">
            Don't have an account? <a href="/sign-up?redirect=%s">Sign up</a>
        </div>
    </div>

    <!-- Firebase SDK -->
    <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-auth-compat.js"></script>
    <script>
        // Initialize Firebase
        const firebaseConfig = {
            apiKey: '%s',
            authDomain: '%s',
            projectId: '%s'
        };
        firebase.initializeApp(firebaseConfig);
        const auth = firebase.auth();

        // Check for email verification error or email parameter
        const urlParams = new URLSearchParams(window.location.search);
        const emailParam = urlParams.get('email');
        const errorParam = urlParams.get('error');

        if (emailParam) {
            document.getElementById('email').value = emailParam;
        }

        if (errorParam === 'email_not_verified') {
            const errorDiv = document.getElementById('error');
            errorDiv.style.color = '#e74c3c';
            errorDiv.textContent = 'Please verify your email address before signing in. Check your inbox for the verification email.';
            errorDiv.classList.add('show');
        }

        // Enhanced logging function
        const logError = function(message, error) {
            const timestamp = new Date().toISOString();
            const logMessage = '[' + timestamp + '] ' + message;
            console.error(logMessage, error);
            // Also log to page for visibility
            const logDiv = document.createElement('div');
            logDiv.style.cssText = 'position:fixed;top:10px;right:10px;background:#ff4444;color:white;padding:10px;border-radius:5px;z-index:10000;max-width:400px;font-size:12px;';
            logDiv.textContent = logMessage + (error ? ': ' + error.message : '');
            document.body.appendChild(logDiv);
            // Keep for 10 seconds
            setTimeout(function() { logDiv.remove(); }, 10000);
        };

        const logInfo = function(message, data) {
            const timestamp = new Date().toISOString();
            const logMessage = '[' + timestamp + '] ' + message;
            console.log(logMessage, data || '');
        };

        // Track last email verification send time to prevent rate limiting
        let lastVerificationEmailTime = 0;
        const VERIFICATION_EMAIL_COOLDOWN = 60000; // 60 seconds cooldown

        // Handle form submission - prevent multiple submissions
        let isSubmitting = false;
        document.getElementById('signin-form').addEventListener('submit', async (e) => {
            e.preventDefault();

            // Prevent multiple simultaneous submissions
            if (isSubmitting) {
                logInfo('⚠️ Sign-in already in progress, ignoring duplicate submission');
                return;
            }

            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            const submitBtn = document.getElementById('submit-btn');
            const errorDiv = document.getElementById('error');

            logInfo('🔐 Starting email/password sign-in', { email: email.substring(0, 3) + '***' });

            isSubmitting = true;
            submitBtn.disabled = true;
            errorDiv.classList.remove('show');
            errorDiv.textContent = '';

            try {
                logInfo('🔐 Calling auth.signInWithEmailAndPassword...');
                const userCredential = await auth.signInWithEmailAndPassword(email, password);
                logInfo('✅ Email sign-in successful', { email: userCredential.user.email });

                // Check if email is verified
                if (!userCredential.user.emailVerified) {
                    logInfo('⚠️ Email not verified');
                    // Don't send verification email again - it was already sent during sign-up
                    // Sending it again here can trigger rate limiting
                    errorDiv.style.color = '#e74c3c';
                    errorDiv.textContent = 'Please verify your email address before signing in. Check your inbox for the verification email.';
                    errorDiv.classList.add('show');
                    submitBtn.disabled = false;
                    isSubmitting = false;
                    return;
                }

                logInfo('🔐 Getting ID token...');
                const token = await userCredential.user.getIdToken();
                logInfo('✅ Token obtained', {
                    tokenLength: token ? token.length : 0,
                    tokenPrefix: token ? token.substring(0, 20) + '...' : 'none'
                });

                // Store token in cookie (for server-side auth) and sessionStorage (for client-side)
                // Cookie expires in 1 hour (3600 seconds)
                // Use SameSite=None; Secure for HTTPS (allows cross-site), SameSite=Lax for HTTP (local dev)
                // Set cookie with path=/ to ensure it's sent for all routes
                // No domain specified = cookie is set for current domain
                const isSecure = window.location.protocol === 'https:';
                const sameSiteAttr = isSecure ? 'SameSite=None; Secure' : 'SameSite=Lax';
                document.cookie = 'firebase_token=' + encodeURIComponent(token) + '; path=/; max-age=3600; ' + sameSiteAttr;
                console.log('🔍 Cookie set:', document.cookie.split(';').find(c => c.trim().startsWith('firebase_token=')));
                sessionStorage.setItem('firebase_token', token);
                logInfo('✅ Token stored in cookie and sessionStorage');

                // Redirect without token in URL (token is now in cookie)
                const redirectPath = '%s';
                const redirectUrl = window.location.origin + redirectPath;
                logInfo('🔐 Redirecting to', { redirectUrl });
                window.location.href = redirectUrl;
            } catch (error) {
                logError('❌ Email sign-in error', error);
                const errorMessage = error.message || 'Sign in failed. Please try again.';
                const errorCode = error.code || 'unknown';

                errorDiv.style.color = '#e74c3c';

                // Handle rate limiting specifically
                if (errorCode === 'auth/too-many-requests') {
                    errorDiv.textContent = 'Too many requests. Please wait a few minutes before trying again.';
                } else {
                    errorDiv.textContent = errorMessage + ' (Code: ' + errorCode + ')';
                }
                errorDiv.classList.add('show');
                submitBtn.disabled = false;
                isSubmitting = false;
            }
        });

        // Handle Google sign-in with comprehensive logging
        document.getElementById('google-btn').addEventListener('click', async () => {
            const provider = new firebase.auth.GoogleAuthProvider();
            const submitBtn = document.getElementById('google-btn');
            const errorDiv = document.getElementById('error');

            // Enhanced logging that persists
            const logError = (message, error) => {
                const timestamp = new Date().toISOString();
                const logMessage = '[' + timestamp + '] ' + message;
                console.error(logMessage, error);
                // Also log to page for visibility
                const logDiv = document.createElement('div');
                logDiv.style.cssText = 'position:fixed;top:10px;right:10px;background:#ff4444;color:white;padding:10px;border-radius:5px;z-index:10000;max-width:400px;font-size:12px;';
                logDiv.textContent = logMessage + (error ? ': ' + error.message : '');
                document.body.appendChild(logDiv);
                // Keep for 10 seconds
                setTimeout(function() { logDiv.remove(); }, 10000);
            };

            const logInfo = (message, data) => {
                const timestamp = new Date().toISOString();
                const logMessage = '[' + timestamp + '] ' + message;
                console.log(logMessage, data || '');
            };

            logInfo('🔐 Starting Google sign-in', {
                origin: window.location.origin,
                userAgent: navigator.userAgent,
                isInIframe: window !== window.top
            });

            submitBtn.disabled = true;
            errorDiv.classList.remove('show');
            errorDiv.textContent = '';

            try {
                logInfo('🔐 Calling auth.signInWithPopup...', {
                    providerId: provider.providerId,
                    origin: window.location.origin,
                    referrer: document.referrer
                });

                // Add global error handlers to catch COOP errors
                const errorHandler = function(event) {
                    logError('❌ Global error in popup flow', {
                        type: event.type,
                        message: event.message || event.reason,
                        filename: event.filename,
                        lineno: event.lineno,
                        colno: event.colno,
                        error: event.error ? event.error.toString() : 'none'
                    });
                };
                const rejectionHandler = function(event) {
                    logError('❌ Unhandled promise rejection in popup flow', {
                        reason: event.reason ? event.reason.toString() : 'unknown',
                        promise: event.promise
                    });
                };
                window.addEventListener('error', errorHandler);
                window.addEventListener('unhandledrejection', rejectionHandler);

                const result = await auth.signInWithPopup(provider);

                // Remove error handlers after success
                window.removeEventListener('error', errorHandler);
                window.removeEventListener('unhandledrejection', rejectionHandler);

                logInfo('✅ Popup sign-in successful', {
                    user: result.user ? result.user.email : 'no user',
                    hasCredential: !!result.credential,
                    credentialProvider: result.credential ? result.credential.providerId : 'none'
                });

                logInfo('🔐 Getting ID token...');
                const token = await result.user.getIdToken();
                logInfo('✅ Token obtained', {
                    tokenLength: token ? token.length : 0,
                    tokenPrefix: token ? token.substring(0, 20) + '...' : 'none'
                });

                // Store token in cookie (for server-side auth) and sessionStorage (for client-side)
                // Cookie expires in 1 hour (3600 seconds)
                // Use SameSite=None; Secure for HTTPS (allows cross-site), SameSite=Lax for HTTP (local dev)
                // Set cookie with path=/ to ensure it's sent for all routes
                // No domain specified = cookie is set for current domain
                const isSecure = window.location.protocol === 'https:';
                const sameSiteAttr = isSecure ? 'SameSite=None; Secure' : 'SameSite=Lax';
                document.cookie = 'firebase_token=' + encodeURIComponent(token) + '; path=/; max-age=3600; ' + sameSiteAttr;
                console.log('🔍 Cookie set:', document.cookie.split(';').find(c => c.trim().startsWith('firebase_token=')));
                sessionStorage.setItem('firebase_token', token);
                logInfo('✅ Token stored in cookie and sessionStorage');

                // Redirect without token in URL (token is now in cookie)
                const redirectPath = '%s';
                const redirectUrl = window.location.origin + redirectPath;
                logInfo('🔐 Redirecting to', { redirectUrl });
                window.location.href = redirectUrl;
            } catch (error) {
                logError('❌ Google sign-in error', error);
                const errorMessage = error.message || 'Google sign in failed. Please try again.';
                const errorCode = error.code || 'unknown';

                // Enhanced error display
                errorDiv.style.color = '#e74c3c';
                errorDiv.textContent = errorMessage + ' (Code: ' + errorCode + ')';
                errorDiv.classList.add('show');

                // Log specific error types
                if (error.code === 'auth/popup-closed-by-user') {
                    logError('❌ User closed popup window', error);
                } else if (error.code === 'auth/popup-blocked') {
                    logError('❌ Popup blocked by browser', error);
                } else if (error.code === 'auth/network-request-failed') {
                    logError('❌ Network error during sign-in', error);
                } else if (error.code === 'auth/account-exists-with-different-credential') {
                    logError('❌ Account exists with different credential', error);
                } else {
                    // Log full error details for unknown errors
                    logError('❌ Unknown Google sign-in error', {
                        code: error.code,
                        message: error.message,
                        stack: error.stack,
                        name: error.name
                    });
                }

                submitBtn.disabled = false;
            }
        });
    </script>
</body>
</html>`, redirectURL, firebaseAPIKey, firebaseAuthDomain, homeData.FirebaseProjectID, redirectURL, redirectURL)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	// Allow cross-origin popups for Firebase authentication
	// Cross-Origin-Opener-Policy: same-origin-allow-popups allows popups to communicate back
	w.Header().Set("Cross-Origin-Opener-Policy", "same-origin-allow-popups")
	w.Header().Set("Cross-Origin-Embedder-Policy", "unsafe-none")
	log.Printf("🔐 Sign-in page response headers set [redirect=%s, COOP=same-origin-allow-popups]", sanitizeForLog(redirectURL, 200))
	w.Write([]byte(html))
}

// serveSignUpPage serves the sign-up page with Firebase Authentication
func serveSignUpPage(w http.ResponseWriter, r *http.Request, homeData HomePageData) {
	// Log sign-up page access with client details
	clientIP := r.Header.Get("X-Forwarded-For")
	if clientIP == "" {
		clientIP = r.RemoteAddr
	}
	userAgent := r.Header.Get("User-Agent")

	log.Printf("📝 Sign-up page accessed [ip=%s, user-agent=%s]", sanitizeForLog(clientIP, 50), sanitizeForLog(userAgent, 100))

	if !homeData.AuthEnabled {
		log.Printf("❌ Sign-up attempted but authentication is disabled [ip=%s]", clientIP)
		http.Error(w, "Authentication is not enabled", http.StatusNotFound)
		return
	}

	// Get redirect URL from query parameter
	redirectURL := r.URL.Query().Get("redirect")
	if redirectURL == "" {
		redirectURL = "/"
	}

	log.Printf("📝 Sign-up page rendered [ip=%s, redirect=%s]", sanitizeForLog(clientIP, 50), sanitizeForLog(redirectURL, 200))

	// Get Firebase config from environment
	firebaseAPIKey := os.Getenv("FIREBASE_API_KEY")
	firebaseAuthDomain := os.Getenv("FIREBASE_AUTH_DOMAIN")
	if firebaseAuthDomain == "" && homeData.FirebaseProjectID != "" {
		firebaseAuthDomain = fmt.Sprintf("%s.firebaseapp.com", homeData.FirebaseProjectID)
	}

	html := fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sign Up - E-Skimming Labs</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .signup-container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 400px;
            width: 100%%;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 28px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            color: #333;
            font-weight: 500;
            font-size: 14px;
        }
        input {
            width: 100%%;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 6px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%%;
            padding: 12px;
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 10px;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }
        .error {
            color: #e74c3c;
            font-size: 14px;
            margin-top: 10px;
            display: none;
        }
        .error.show {
            display: block;
        }
        .divider {
            text-align: center;
            margin: 20px 0;
            color: #999;
            font-size: 14px;
            position: relative;
        }
        .divider::before,
        .divider::after {
            content: '';
            position: absolute;
            top: 50%%;
            width: 40%%;
            height: 1px;
            background: #ddd;
        }
        .divider::before {
            left: 0;
        }
        .divider::after {
            right: 0;
        }
        .google-btn {
            background: white;
            color: #333;
            border: 1px solid #ddd;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
        }
        .google-btn:hover {
            background: #f5f5f5;
        }
        .signin-link {
            text-align: center;
            margin-top: 20px;
            font-size: 14px;
            color: #666;
        }
        .signin-link a {
            color: #667eea;
            text-decoration: none;
            font-weight: 500;
        }
        .signin-link a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="signup-container">
        <h1>Sign Up</h1>
        <p class="subtitle">Create your E-Skimming Labs account</p>

        <form id="signup-form">
            <div class="form-group">
                <label for="email">Email</label>
                <input type="email" id="email" name="email" required autocomplete="email">
            </div>
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" name="password" required autocomplete="new-password" minlength="6">
            </div>
            <div class="error" id="error"></div>
            <button type="submit" id="submit-btn">Sign Up</button>
        </form>

        <div class="divider">or</div>

        <button class="google-btn" id="google-btn">
            <svg width="18" height="18" viewBox="0 0 18 18">
                <path fill="#4285F4" d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.874 2.684-6.615z"/>
                <path fill="#34A853" d="M9 18c2.43 0 4.467-.806 5.96-2.184l-2.908-2.258c-.806.54-1.837.86-3.052.86-2.347 0-4.337-1.584-5.046-3.711H.957v2.332C2.438 15.983 5.482 18 9 18z"/>
                <path fill="#FBBC05" d="M3.954 10.707c-.18-.54-.282-1.117-.282-1.707s.102-1.167.282-1.707V4.961H.957C.348 6.175 0 7.55 0 9s.348 2.825.957 4.039l3.997-3.332z"/>
                <path fill="#EA4335" d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0 5.482 0 2.438 2.017.957 4.961L3.954 7.293C4.663 5.163 6.653 3.58 9 3.58z"/>
            </svg>
            Sign up with Google
        </button>

        <div class="signin-link">
            Already have an account? <a href="/sign-in?redirect=%s">Sign in</a>
        </div>
    </div>

    <!-- Firebase SDK -->
    <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-auth-compat.js"></script>
    <script>
        // Initialize Firebase
        const firebaseConfig = {
            apiKey: '%s',
            authDomain: '%s',
            projectId: '%s'
        };
        firebase.initializeApp(firebaseConfig);
        const auth = firebase.auth();

        // Handle form submission - prevent multiple submissions
        let isSigningUp = false;
        document.getElementById('signup-form').addEventListener('submit', async (e) => {
            e.preventDefault();

            // Prevent multiple simultaneous submissions
            if (isSigningUp) {
                console.log('⚠️ Sign-up already in progress, ignoring duplicate submission');
                return;
            }

            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            const submitBtn = document.getElementById('submit-btn');
            const errorDiv = document.getElementById('error');

            isSigningUp = true;
            submitBtn.disabled = true;
            errorDiv.classList.remove('show');
            errorDiv.textContent = '';

            try {
                const userCredential = await auth.createUserWithEmailAndPassword(email, password);

                // Send email verification (only once per sign-up)
                await userCredential.user.sendEmailVerification();

                // Show success message
                errorDiv.style.color = '#27ae60';
                errorDiv.textContent = 'Account created! Please check your email to verify your account before signing in.';
                errorDiv.classList.add('show');

                // Redirect to sign-in page after 3 seconds
                setTimeout(() => {
                    const redirectPath = '%s';
                    window.location.href = '/sign-in?redirect=' + encodeURIComponent(redirectPath) + '&email=' + encodeURIComponent(email);
                }, 3000);
            } catch (error) {
                errorDiv.style.color = '#e74c3c';
                const errorMessage = error.message || 'Sign up failed. Please try again.';
                const errorCode = error.code || 'unknown';

                // Handle rate limiting specifically
                if (errorCode === 'auth/too-many-requests') {
                    errorDiv.textContent = 'Too many requests. Please wait a few minutes before trying again.';
                } else {
                    errorDiv.textContent = errorMessage + ' (Code: ' + errorCode + ')';
                }
                errorDiv.classList.add('show');
                submitBtn.disabled = false;
                isSigningUp = false;
            }
        });

        // Handle Google sign-up
        document.getElementById('google-btn').addEventListener('click', async () => {
            const provider = new firebase.auth.GoogleAuthProvider();
            const submitBtn = document.getElementById('google-btn');
            const errorDiv = document.getElementById('error');

            submitBtn.disabled = true;
            errorDiv.classList.remove('show');
            errorDiv.textContent = '';

            try {
                const result = await auth.signInWithPopup(provider);
                const token = await result.user.getIdToken();

                // Store token in cookie (for server-side auth) and sessionStorage (for client-side)
                // Cookie expires in 1 hour (3600 seconds)
                // Use SameSite=None; Secure for HTTPS (allows cross-site), SameSite=Lax for HTTP (local dev)
                // Set cookie with path=/ to ensure it's sent for all routes
                // No domain specified = cookie is set for current domain
                const isSecure = window.location.protocol === 'https:';
                const sameSiteAttr = isSecure ? 'SameSite=None; Secure' : 'SameSite=Lax';
                document.cookie = 'firebase_token=' + encodeURIComponent(token) + '; path=/; max-age=3600; ' + sameSiteAttr;
                console.log('🔍 Cookie set:', document.cookie.split(';').find(c => c.trim().startsWith('firebase_token=')));
                sessionStorage.setItem('firebase_token', token);

                // Redirect without token in URL (token is now in cookie)
                const redirectPath = '%s';
                const redirectUrl = window.location.origin + redirectPath;
                window.location.href = redirectUrl;
            } catch (error) {
                errorDiv.textContent = error.message || 'Google sign up failed. Please try again.';
                errorDiv.classList.add('show');
                submitBtn.disabled = false;
            }
        });
    </script>
</body>
</html>`, redirectURL, firebaseAPIKey, firebaseAuthDomain, homeData.FirebaseProjectID, redirectURL, redirectURL)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	// Allow cross-origin popups for Firebase authentication
	// Cross-Origin-Opener-Policy: same-origin-allow-popups allows popups to communicate back
        w.Header().Set("Cross-Origin-Opener-Policy", "same-origin-allow-popups")
        w.Header().Set("Cross-Origin-Embedder-Policy", "unsafe-none")
        log.Printf("🔐 Sign-up page response headers set [redirect=%s, COOP=same-origin-allow-popups]", sanitizeForLog(redirectURL, 200))
        w.Write([]byte(html))
}

// checkServiceHealth checks if critical services are ready
// Returns: services status, allReady flag, and apiAvailable flag
func checkServiceHealth(environment string) ([]ServiceStatus, bool, bool) {
	services := []ServiceStatus{
		{Name: "Traefik", Status: "checking"},
		{Name: "Home Index", Status: "checking"},
		{Name: "SEO Service", Status: "checking"},
		{Name: "Analytics Service", Status: "checking"},
		{Name: "Lab 1", Status: "checking"},
		{Name: "Lab 2", Status: "checking"},
		{Name: "Lab 3", Status: "checking"},
	}

	allReady := true
	apiAvailable := false

	// In local environment, check via Traefik API
	if environment == "local" {
		traefikAPI := "http://traefik:8080"
		traefikWeb := "http://traefik:80"
		client := &http.Client{Timeout: 2 * time.Second}

		// Check Traefik itself - ping endpoint is on web port (80), not API port (8080)
		resp, err := client.Get(traefikWeb + "/ping")
		if err == nil && resp.StatusCode == 200 {
			services[0].Status = "up"
		} else {
			// If ping fails, check API endpoint as fallback
			resp, err = client.Get(traefikAPI + "/api/overview")
			if err == nil && resp.StatusCode == 200 {
				services[0].Status = "up"
				apiAvailable = true
			} else {
				services[0].Status = "down"
				// Traefik API unavailable - can't check other services
				return services, false, false
			}
		}

		// Check services via Traefik API
		resp, err = client.Get(traefikAPI + "/api/http/services")
		if err == nil && resp.StatusCode == 200 {
			apiAvailable = true
			defer resp.Body.Close()
			body, _ := io.ReadAll(resp.Body)
			var traefikServices []map[string]interface{}
			if json.Unmarshal(body, &traefikServices) == nil {
				serviceMap := make(map[string]string)
				for _, svc := range traefikServices {
					if name, ok := svc["name"].(string); ok {
						if serverStatus, ok := svc["serverStatus"].(map[string]interface{}); ok {
							// Check if any server is UP
							for _, status := range serverStatus {
								if statusStr, ok := status.(string); ok && statusStr == "UP" {
									serviceMap[name] = "up"
									break
								}
							}
							if serviceMap[name] == "" {
								serviceMap[name] = "down"
							}
						}
					}
				}

				// Map Traefik service names to our service names
				if serviceMap["home-index@docker"] == "up" {
					services[1].Status = "up"
				} else {
					services[1].Status = "down"
					allReady = false
				}

				// SEO and Analytics are optional - don't block if they're down
				if serviceMap["home-seo@docker"] == "up" {
					services[2].Status = "up"
				} else {
					services[2].Status = "down"
					// Don't block on SEO service
				}

				if serviceMap["labs-analytics@docker"] == "up" {
					services[3].Status = "up"
				} else {
					services[3].Status = "down"
					// Don't block on Analytics service
				}

				if serviceMap["lab1@docker"] == "up" {
					services[4].Status = "up"
				} else {
					services[4].Status = "down"
					allReady = false
				}

				if serviceMap["lab2-vulnerable-site@docker"] == "up" {
					services[5].Status = "up"
				} else {
					services[5].Status = "down"
					allReady = false
				}

				if serviceMap["lab3-vulnerable-site@docker"] == "up" {
					services[6].Status = "up"
				} else {
					services[6].Status = "down"
					allReady = false
				}
			}
		} else {
			// Traefik API unavailable - mark all services as unknown
			apiAvailable = false
			for i := range services {
				if services[i].Status == "checking" {
					services[i].Status = "down"
				}
			}
			allReady = false
		}
	} else {
		// In staging/production, services are always considered ready after startup
		// (Cloud Run handles health checks)
		for i := range services {
			services[i].Status = "up"
		}
		allReady = true
		apiAvailable = true
	}

	return services, allReady, apiAvailable
}

// serveStatusPage serves the startup status page
func serveStatusPage(w http.ResponseWriter, r *http.Request, homeData HomePageData) {
	environment := os.Getenv("ENVIRONMENT")
	if environment == "" {
		environment = "local"
	}

	services, allReady, apiAvailable := checkServiceHealth(environment)

	// Build refresh URL
	scheme := "http"
	if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
		scheme = "https"
	}
	host := r.Header.Get("X-Forwarded-Host")
	if host == "" {
		host = r.Host
	}
	refreshURL := fmt.Sprintf("%s://%s/status", scheme, host)
	dashboardURL := "http://localhost:8081/dashboard/"
	if host != "localhost:8080" && host != "127.0.0.1:8080" {
		if strings.Contains(host, ":") {
			parts := strings.Split(host, ":")
			dashboardURL = fmt.Sprintf("%s://%s:8081/dashboard/", scheme, parts[0])
		}
	}

	statusData := StatusPageData{
		Services:      services,
		AllReady:      allReady,
		APIUnavailable: !apiAvailable,
		Environment:   environment,
		RefreshURL:    refreshURL,
		DashboardURL:  dashboardURL,
	}

	tmpl := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E-Skimming Labs - Starting Up</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #333;
        }
        .container {
            background: white;
            border-radius: 16px;
            padding: 2rem;
            max-width: 600px;
            width: 90%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 {
            color: #667eea;
            margin-bottom: 0.5rem;
            font-size: 2rem;
        }
        .subtitle {
            color: #666;
            margin-bottom: 2rem;
            font-size: 1rem;
        }
        .service-list {
            list-style: none;
            margin: 1.5rem 0;
        }
        .service-item {
            display: flex;
            align-items: center;
            padding: 0.75rem;
            margin: 0.5rem 0;
            border-radius: 8px;
            background: #f5f5f5;
        }
        .service-name {
            flex: 1;
            font-weight: 500;
        }
        .status {
            padding: 0.25rem 0.75rem;
            border-radius: 12px;
            font-size: 0.875rem;
            font-weight: 600;
        }
        .status.up {
            background: #10b981;
            color: white;
        }
        .status.down {
            background: #ef4444;
            color: white;
        }
        .status.checking {
            background: #f59e0b;
            color: white;
        }
        .spinner {
            display: inline-block;
            width: 16px;
            height: 16px;
            border: 2px solid #f3f3f3;
            border-top: 2px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-right: 0.5rem;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .ready-message {
            background: #10b981;
            color: white;
            padding: 1rem;
            border-radius: 8px;
            text-align: center;
            margin-top: 1.5rem;
            font-weight: 600;
        }
        .auto-refresh {
            text-align: center;
            color: #666;
            font-size: 0.875rem;
            margin-top: 1rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 E-Skimming Labs</h1>
        {{if .APIUnavailable}}
        <p class="subtitle" style="color: #ef4444; font-weight: 600;">
            ⚠️ Unable to check service status - Traefik API is not accessible.
            <br>Please check the <a href="{{.DashboardURL}}" target="_blank" style="color: #667eea;">Traefik dashboard</a> for detailed service information.
        </p>
        {{else}}
        <p class="subtitle">Starting up services...</p>
        {{end}}

        <ul class="service-list">
            {{range .Services}}
            <li class="service-item">
                <span class="service-name">{{.Name}}</span>
                <span class="status {{.Status}}">
                    {{if eq .Status "checking"}}<span class="spinner"></span>{{end}}
                    {{if eq .Status "up"}}✓ Ready{{end}}
                    {{if eq .Status "down"}}✗ Starting...{{end}}
                </span>
            </li>
            {{end}}
        </ul>

        {{if .AllReady}}
        <div class="ready-message">
            ✅ All services are ready! Redirecting...
        </div>
        <script>
            setTimeout(function() {
                window.location.href = '/';
            }, 1000);
        </script>
        {{else}}
        <div style="text-align: center; margin-top: 1.5rem;">
            <a href="{{.DashboardURL}}" class="dashboard-link" target="_blank" style="display: inline-block; padding: 0.75rem 1.5rem; background: #667eea; color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">
                📊 View Traefik Dashboard
            </a>
        </div>
        <div class="auto-refresh">
            <span class="spinner"></span> Checking again in 3 seconds...
        </div>
        <script>
            setTimeout(function() {
                window.location.reload();
            }, 3000);
        </script>
        {{end}}
    </div>
</body>
</html>`

	t, err := template.New("status").Parse(tmpl)
	if err != nil {
		log.Printf("Error parsing status template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	var html strings.Builder
	if err := t.Execute(&html, statusData); err != nil {
		log.Printf("Error executing status template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(html.String()))
}

// serveStatusAPI serves the status as JSON
func serveStatusAPI(w http.ResponseWriter, r *http.Request, homeData HomePageData) {
	environment := os.Getenv("ENVIRONMENT")
	if environment == "" {
		environment = "local"
	}

	services, allReady, apiAvailable := checkServiceHealth(environment)

	response := map[string]interface{}{
		"services": services,
		"allReady": allReady,
		"apiAvailable": apiAvailable,
		"environment": environment,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// serveStartup404 serves a custom 404 page when services are still starting
// apiUnavailable indicates if Traefik API is not accessible
func serveStartup404(w http.ResponseWriter, r *http.Request, serviceStatuses []ServiceStatus, apiUnavailable bool) {
	// Build Traefik dashboard URL
	scheme := "http"
	if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
		scheme = "https"
	}
	host := r.Header.Get("X-Forwarded-Host")
	if host == "" {
		host = r.Host
	}
	// Traefik dashboard is on port 8081
	dashboardURL := "http://localhost:8081/dashboard/"
	if host != "localhost:8080" && host != "127.0.0.1:8080" {
		// If accessed via different host, try to construct dashboard URL
		if strings.Contains(host, ":") {
			parts := strings.Split(host, ":")
			dashboardURL = fmt.Sprintf("%s://%s:8081/dashboard/", scheme, parts[0])
		}
	}

	tmpl := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E-Skimming Labs - Services Starting</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #333;
        }
        .container {
            background: white;
            border-radius: 16px;
            padding: 2rem;
            max-width: 600px;
            width: 90%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
        }
        h1 {
            color: #667eea;
            margin-bottom: 1rem;
            font-size: 2rem;
        }
        .message {
            color: #666;
            margin-bottom: 2rem;
            font-size: 1.1rem;
            line-height: 1.6;
        }
        .status-list {
            text-align: left;
            margin: 1.5rem 0;
            background: #f5f5f5;
            border-radius: 8px;
            padding: 1rem;
        }
        .status-item {
            display: flex;
            justify-content: space-between;
            padding: 0.5rem 0;
            border-bottom: 1px solid #e0e0e0;
        }
        .status-item:last-child {
            border-bottom: none;
        }
        .status-name {
            font-weight: 500;
        }
        .status {
            padding: 0.25rem 0.75rem;
            border-radius: 12px;
            font-size: 0.875rem;
            font-weight: 600;
        }
        .status.up {
            background: #10b981;
            color: white;
        }
        .status.down {
            background: #ef4444;
            color: white;
        }
        .status.checking {
            background: #f59e0b;
            color: white;
        }
        .dashboard-link {
            display: inline-block;
            margin-top: 1.5rem;
            padding: 0.75rem 1.5rem;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            transition: background 0.2s;
        }
        .dashboard-link:hover {
            background: #5568d3;
        }
        .auto-refresh {
            margin-top: 1rem;
            color: #666;
            font-size: 0.875rem;
        }
        .spinner {
            display: inline-block;
            width: 16px;
            height: 16px;
            border: 2px solid #f3f3f3;
            border-top: 2px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-right: 0.5rem;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 E-Skimming Labs</h1>
        {{if .APIUnavailable}}
        <p class="message" style="color: #ef4444; font-weight: 600;">
            ⚠️ Unable to check service status - Traefik API is not accessible.
            <br>Please check the Traefik dashboard for detailed service information.
        </p>
        {{else}}
        <p class="message">
            Services are still starting up. Some services may not be ready yet.
        </p>
        {{end}}

        <div class="status-list">
            {{range .Services}}
            <div class="status-item">
                <span class="status-name">{{.Name}}</span>
                <span class="status {{.Status}}">
                    {{if eq .Status "checking"}}<span class="spinner"></span>Starting{{end}}
                    {{if eq .Status "up"}}✓ Ready{{end}}
                    {{if eq .Status "down"}}✗ Starting...{{end}}
                </span>
            </div>
            {{end}}
        </div>

        <a href="{{.DashboardURL}}" class="dashboard-link" target="_blank">
            📊 View Traefik Dashboard
        </a>

        <div class="auto-refresh">
            <span class="spinner"></span> This page will refresh automatically...
        </div>
    </div>

    <script>
        // Auto-refresh every 5 seconds
        setTimeout(function() {
            window.location.reload();
        }, 5000);
    </script>
</body>
</html>`

	type Startup404Data struct {
		Services     []ServiceStatus
		DashboardURL string
		APIUnavailable bool
	}

	data := Startup404Data{
		Services:      serviceStatuses,
		DashboardURL:  dashboardURL,
		APIUnavailable: apiUnavailable,
	}

	t, err := template.New("startup404").Parse(tmpl)
	if err != nil {
		log.Printf("Error parsing startup404 template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusNotFound)

	var html strings.Builder
	if err := t.Execute(&html, data); err != nil {
		log.Printf("Error executing startup404 template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Write([]byte(html.String()))
}
