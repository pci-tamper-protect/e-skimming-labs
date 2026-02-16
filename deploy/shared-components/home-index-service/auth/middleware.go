package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path"
	"strings"
)

// AuthContextKey is the key for storing auth info in request context
type AuthContextKey string

const (
	// UserInfoKey is the context key for user information
	UserInfoKey AuthContextKey = "userInfo"
)

// sanitizeEmail sanitizes an email address to show only first 2 chars + "@" + domain
// Example: "abraham@example.com" -> "ab@example.com"
func sanitizeEmail(email string) string {
	atIndex := strings.Index(email, "@")
	if atIndex == -1 {
		// Not a valid email format, return as-is
		return email
	}

	localPart := email[:atIndex]
	domain := email[atIndex+1:]

	// Show first 2 characters of local part, or all if less than 2
	if len(localPart) <= 2 {
		return email // Too short to sanitize meaningfully
	}

	return localPart[:2] + "@" + domain
}

// AuthMiddleware creates HTTP middleware for authentication
func AuthMiddleware(validator *TokenValidator) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Normalize path using path.Clean which:
			// - Collapses multiple slashes (///x -> /x)
			// - Resolves . and .. components
			// - Removes trailing slashes (except root)
			// - Returns "/" for empty paths
			normalizedPath := path.Clean(r.URL.Path)
			if normalizedPath == "." {
				normalizedPath = "/"
			}

			// Explicit protected paths: always require auth when validator is enabled (no public bypass)
			// Note: /lab1, /lab2, /lab3 are protected by Traefik ForwardAuth, not this middleware
			protectedPathPrefixes := []string{
				"/lab-01-writeup",
				"/lab-02-writeup",
				"/lab-03-writeup",
			}
			isProtectedPath := false
			for _, prefix := range protectedPathPrefixes {
				if normalizedPath == prefix || strings.HasPrefix(normalizedPath, prefix+"/") {
					isProtectedPath = true
					log.Printf("🔒 Auth middleware (protected path): %s (normalized: %s)", r.URL.Path, normalizedPath)
					break
				}
			}

			if !isProtectedPath {
				// Skip auth for public pages: home, mitre-attack, threat-model
				// Also skip health check, static assets, and auth API endpoints
				publicPaths := []string{
					"/",
					"/mitre-attack",
					"/threat-model",
					"/health",
					"/status",     // Startup status page (public)
					"/sign-in",    // Sign-in page (public)
					"/sign-up",    // Sign-up page (public)
					"/api/auth",   // All auth API endpoints (sign-in, validate, etc.)
					"/api/labs",   // Labs listing API (public)
					"/api/status", // Status API endpoint (public)
				}

				isPublicPath := false
				for _, path := range publicPaths {
					if normalizedPath == path || strings.HasPrefix(normalizedPath, path+"/") {
						isPublicPath = true
						break
					}
				}

				if isPublicPath || strings.HasPrefix(r.URL.Path, "/static/") {
					log.Printf("🔓 Skipping auth for public path: %s (normalized: %s)", r.URL.Path, normalizedPath)
					next.ServeHTTP(w, r)
					return
				}

				log.Printf("🔒 Auth middleware checking: %s (normalized: %s)", r.URL.Path, normalizedPath)
			}

			// If auth is disabled, proceed without validation
			if !validator.IsEnabled() {
				next.ServeHTTP(w, r)
				return
			}

			// Extract token from various sources
			token := extractToken(r)

			// Validate token
			userInfo, err := validator.ValidateToken(r.Context(), token)
			if err != nil {
				if validator.IsRequired() {
					// Auth required but validation failed
					log.Printf("❌ Authentication required but failed: %v", err)
					respondAuthError(w, r, http.StatusUnauthorized, "Authentication required", validator.GetMainAppURL())
					return
				}
				// Auth optional, continue without user info
				log.Printf("⚠️ Token validation failed (optional auth): %v", err)
				next.ServeHTTP(w, r)
				return
			}

			// If auth is required but no token provided
			if validator.IsRequired() && token == "" {
				log.Printf("❌ Authentication required but no token provided")
				respondAuthError(w, r, http.StatusUnauthorized, "Authentication required", validator.GetMainAppURL())
				return
			}

			// Check email verification if user info is available
			if userInfo != nil && validator.IsRequired() && !userInfo.EmailVerified {
				log.Printf("❌ Email not verified for user: %s", sanitizeEmail(userInfo.Email))
				// For browser requests, redirect to sign-in with a message
				acceptHeader := r.Header.Get("Accept")
				isBrowserRequest := strings.Contains(acceptHeader, "text/html") ||
					acceptHeader == "" ||
					strings.Contains(acceptHeader, "*/*")
				if isBrowserRequest {
					// Use X-Forwarded-Host if available (when behind proxy like Traefik),
					// otherwise use request's Host header to avoid container hostname issues
					scheme := "http"
					if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
						scheme = "https"
					}
					host := r.Header.Get("X-Forwarded-Host")
					if host == "" {
						host = r.Host
					}
					redirectURL := fmt.Sprintf("%s://%s/sign-in?error=email_not_verified&email=%s", scheme, host, userInfo.Email)
					http.Redirect(w, r, redirectURL, http.StatusFound)
					return
				}
				// For API requests, return 403
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusForbidden)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"error":   "email_not_verified",
					"message": "Email verification required",
				})
				return
			}

			// Add user info to request context
			if userInfo != nil {
				ctx := context.WithValue(r.Context(), UserInfoKey, userInfo)
				r = r.WithContext(ctx)
				log.Printf("✅ Request authenticated (user: %s, email: %s, verified: %v)", userInfo.UserID, sanitizeEmail(userInfo.Email), userInfo.EmailVerified)
			}

			next.ServeHTTP(w, r)
		})
	}
}

// extractToken extracts the Firebase token from the request
// Checks: Authorization header, cookie, query parameter
func extractToken(r *http.Request) string {
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
		return cookie.Value
	}

	// 3. Check query parameter (for initial redirects)
	token := r.URL.Query().Get("token")
	if token != "" {
		return token
	}

	return ""
}

// GetUserInfo extracts user information from request context
func GetUserInfo(r *http.Request) *TokenInfo {
	if userInfo, ok := r.Context().Value(UserInfoKey).(*TokenInfo); ok {
		return userInfo
	}
	return nil
}

// respondAuthError sends an authentication error response
// For browser requests, redirects to sign-in page
// For API requests, returns JSON error
func respondAuthError(w http.ResponseWriter, r *http.Request, statusCode int, message string, mainAppURL string) {
	// Check if this is a browser request (has Accept: text/html)
	acceptHeader := r.Header.Get("Accept")
	isBrowserRequest := strings.Contains(acceptHeader, "text/html") ||
		acceptHeader == "" ||
		strings.Contains(acceptHeader, "*/*")

	if isBrowserRequest && mainAppURL != "" {
		// Redirect browser requests to sign-in page
		// Use X-Forwarded-Host if available (when behind proxy like Traefik),
		// otherwise use request's Host header to avoid container hostname issues
		scheme := "http"
		if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
			scheme = "https"
		}
		host := r.Header.Get("X-Forwarded-Host")
		environment := os.Getenv("ENVIRONMENT")
		if host == "" {
			// In local environment, always use localhost:8080, never use r.Host (internal Docker hostname)
			if environment == "local" {
				host = "127.0.0.1:8080"
			} else {
				host = r.Host
			}
		} else if environment == "local" {
			// Even if X-Forwarded-Host is set, in local environment ensure we use 127.0.0.1:8080
			// X-Forwarded-Host might be set to internal hostname by Traefik
			host = "127.0.0.1:8080"
		}
		redirectURL := fmt.Sprintf("%s://%s/sign-in?redirect=%s", scheme, host, r.URL.String())
		http.Redirect(w, r, redirectURL, http.StatusFound)
		return
	}

	// Return JSON for API requests
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error":     "authentication_required",
		"message":   message,
		"signInUrl": "/api/auth/sign-in-url",
	})
}
