package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
)

// AuthContextKey is the key for storing auth info in request context
type AuthContextKey string

const (
	// UserInfoKey is the context key for user information
	UserInfoKey AuthContextKey = "userInfo"
)

// AuthMiddleware creates HTTP middleware for authentication
func AuthMiddleware(validator *TokenValidator) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Skip auth for public pages: home, mitre-attack, threat-model
			// Also skip health check, static assets, and auth API endpoints
			publicPaths := []string{
				"/",
				"/mitre-attack",
				"/threat-model",
				"/health",
				"/sign-in",   // Sign-in page (public)
				"/sign-up",   // Sign-up page (public)
				"/api/auth",  // All auth API endpoints (sign-in, validate, etc.)
				"/api/labs",  // Labs listing API (public)
			}

			// Normalize path (remove trailing slashes except for root)
			normalizedPath := r.URL.Path
			if normalizedPath != "/" && strings.HasSuffix(normalizedPath, "/") {
				normalizedPath = strings.TrimSuffix(normalizedPath, "/")
			}
			// Handle double slashes
			normalizedPath = strings.ReplaceAll(normalizedPath, "//", "/")

			isPublicPath := false
			for _, path := range publicPaths {
				if normalizedPath == path || strings.HasPrefix(normalizedPath, path+"/") {
					isPublicPath = true
					break
				}
			}

			if isPublicPath || strings.HasPrefix(r.URL.Path, "/static/") {
				next.ServeHTTP(w, r)
				return
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

			// Add user info to request context
			if userInfo != nil {
				ctx := context.WithValue(r.Context(), UserInfoKey, userInfo)
				r = r.WithContext(ctx)
				log.Printf("✅ Request authenticated (user: %s, email: %s)", userInfo.UserID, userInfo.Email)
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
		redirectURL := fmt.Sprintf("%s/sign-in?redirect=%s", mainAppURL, r.URL.String())
		http.Redirect(w, r, redirectURL, http.StatusFound)
		return
	}

	// Return JSON for API requests
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error":   "authentication_required",
		"message": message,
		"signInUrl": "/api/auth/sign-in-url",
	})
}
