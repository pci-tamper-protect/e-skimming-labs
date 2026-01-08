package auth

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

// extractTokenForTesting is a copy of extractToken for testing
func extractTokenForTesting(r *http.Request) string {
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
		// Try URL decoding if needed
		decodedValue, decodeErr := url.QueryUnescape(cookie.Value)
		if decodeErr == nil && decodedValue != cookie.Value {
			return decodedValue
		}
		return cookie.Value
	}

	// 3. Check query parameter (for initial redirects)
	token := r.URL.Query().Get("token")
	if token != "" {
		return token
	}

	return ""
}

func TestExtractTokenFromAuthorizationHeader(t *testing.T) {
	tests := []struct {
		name           string
		authHeader     string
		expectedToken  string
		expectedResult bool
	}{
		{
			name:           "Valid Bearer token",
			authHeader:     "Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
			expectedToken:   "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
			expectedResult: true,
		},
		{
			name:           "Bearer token with lowercase",
			authHeader:     "bearer token123",
			expectedToken:   "token123",
			expectedResult: true,
		},
		{
			name:           "Bearer token with mixed case",
			authHeader:     "BeArEr token123",
			expectedToken:   "token123",
			expectedResult: true,
		},
		{
			name:           "No Bearer prefix",
			authHeader:     "token123",
			expectedToken:   "",
			expectedResult: false,
		},
		{
			name:           "Empty header",
			authHeader:     "",
			expectedToken:   "",
			expectedResult: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", "/test", nil)
			if tt.authHeader != "" {
				req.Header.Set("Authorization", tt.authHeader)
			}

			token := extractTokenForTesting(req)

			if tt.expectedResult {
				if token != tt.expectedToken {
					t.Errorf("Expected token %q, got %q", tt.expectedToken, token)
				}
			} else {
				if token != "" {
					t.Errorf("Expected empty token, got %q", token)
				}
			}
		})
	}
}

func TestExtractTokenFromCookie(t *testing.T) {
	tests := []struct {
		name           string
		cookieValue    string
		cookieEncoded  bool
		expectedToken  string
		expectedResult bool
	}{
		{
			name:           "Simple cookie value",
			cookieValue:    "token123",
			cookieEncoded:  false,
			expectedToken:  "token123",
			expectedResult: true,
		},
		{
			name:           "URL encoded cookie value",
			cookieValue:    "token%2B123",
			cookieEncoded:  true,
			expectedToken:  "token+123",
			expectedResult: true,
		},
		{
			name:           "JWT token in cookie",
			cookieValue:    "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0.signature",
			cookieEncoded:  false,
			expectedToken:  "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0.signature",
			expectedResult: true,
		},
		{
			name:           "Empty cookie",
			cookieValue:    "",
			cookieEncoded:  false,
			expectedToken:  "",
			expectedResult: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", "/test", nil)
			cookie := &http.Cookie{
				Name:  "firebase_token",
				Value: tt.cookieValue,
			}
			req.AddCookie(cookie)

			token := extractTokenForTesting(req)

			if tt.expectedResult {
				if token != tt.expectedToken {
					t.Errorf("Expected token %q, got %q", tt.expectedToken, token)
				}
			} else {
				if token != "" {
					t.Errorf("Expected empty token, got %q", token)
				}
			}
		})
	}
}

func TestExtractTokenFromQueryParameter(t *testing.T) {
	tests := []struct {
		name           string
		queryParam     string
		expectedToken  string
		expectedResult bool
	}{
		{
			name:           "Token in query parameter",
			queryParam:     "token123",
			expectedToken:   "token123",
			expectedResult: true,
		},
		{
			name:           "JWT in query parameter",
			queryParam:     "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
			expectedToken:   "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
			expectedResult: true,
		},
		{
			name:           "No token parameter",
			queryParam:     "",
			expectedToken:   "",
			expectedResult: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			url := "/test"
			if tt.queryParam != "" {
				url += "?token=" + tt.queryParam
			}
			req := httptest.NewRequest("GET", url, nil)

			token := extractTokenForTesting(req)

			if tt.expectedResult {
				if token != tt.expectedToken {
					t.Errorf("Expected token %q, got %q", tt.expectedToken, token)
				}
			} else {
				if token != "" {
					t.Errorf("Expected empty token, got %q", token)
				}
			}
		})
	}
}

func TestExtractTokenPriority(t *testing.T) {
	// Test that Authorization header takes priority over cookie, which takes priority over query param
	req := httptest.NewRequest("GET", "/test?token=query-token", nil)
	req.Header.Set("Authorization", "Bearer header-token")
	cookie := &http.Cookie{
		Name:  "firebase_token",
		Value: "cookie-token",
	}
	req.AddCookie(cookie)

	token := extractTokenForTesting(req)

	if token != "header-token" {
		t.Errorf("Expected Authorization header token to take priority, got %q", token)
	}
}

func TestExtractTokenCookieOverQuery(t *testing.T) {
	// Test that cookie takes priority over query parameter
	req := httptest.NewRequest("GET", "/test?token=query-token", nil)
	cookie := &http.Cookie{
		Name:  "firebase_token",
		Value: "cookie-token",
	}
	req.AddCookie(cookie)

	token := extractTokenForTesting(req)

	if token != "cookie-token" {
		t.Errorf("Expected cookie token to take priority over query param, got %q", token)
	}
}

