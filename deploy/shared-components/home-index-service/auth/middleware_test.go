package auth

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRespondAuthError_BrowserRedirectIsRelative(t *testing.T) {
	tests := []struct {
		name         string
		requestURI   string
		acceptHeader string
		wantLocation string
	}{
		{
			name:         "plain path",
			requestURI:   "/lab1",
			acceptHeader: "text/html",
			wantLocation: "/sign-in?redirect=%2Flab1",
		},
		{
			name:         "path with query string encodes full RequestURI",
			requestURI:   "/lab1?foo=bar&baz=qux",
			acceptHeader: "text/html",
			wantLocation: "/sign-in?redirect=%2Flab1%3Ffoo%3Dbar%26baz%3Dqux",
		},
		{
			name:         "wildcard Accept treated as browser",
			requestURI:   "/protected",
			acceptHeader: "*/*",
			wantLocation: "/sign-in?redirect=%2Fprotected",
		},
		{
			name:         "empty Accept treated as browser",
			requestURI:   "/protected",
			acceptHeader: "",
			wantLocation: "/sign-in?redirect=%2Fprotected",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, tt.requestURI, nil)
			if tt.acceptHeader != "" {
				req.Header.Set("Accept", tt.acceptHeader)
			}
			w := httptest.NewRecorder()

			respondAuthError(w, req, http.StatusUnauthorized, "Authentication required")

			resp := w.Result()
			if resp.StatusCode != http.StatusFound {
				t.Errorf("status = %d, want %d", resp.StatusCode, http.StatusFound)
			}
			loc := resp.Header.Get("Location")
			if loc != tt.wantLocation {
				t.Errorf("Location = %q, want %q", loc, tt.wantLocation)
			}
			if strings.HasPrefix(loc, "http") {
				t.Errorf("Location must be relative, got absolute URL: %q", loc)
			}
		})
	}
}

// TestRespondAuthError_ProxyHeadersIgnored ensures proxy headers that the old
// code used for host/scheme inference do not produce an absolute redirect URL.
func TestRespondAuthError_ProxyHeadersIgnored(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Accept", "text/html")
	req.Header.Set("X-Forwarded-Host", "labs.pcioasis.com")
	req.Header.Set("X-Forwarded-Proto", "https")
	w := httptest.NewRecorder()

	respondAuthError(w, req, http.StatusUnauthorized, "Authentication required")

	loc := w.Result().Header.Get("Location")
	if strings.HasPrefix(loc, "http") {
		t.Errorf("proxy headers must not produce an absolute URL, got: %q", loc)
	}
	if loc != "/sign-in?redirect=%2Fprotected" {
		t.Errorf("Location = %q, want /sign-in?redirect=%%2Fprotected", loc)
	}
}

func TestRespondAuthError_APIRequestReturnsJSON(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/data", nil)
	req.Header.Set("Accept", "application/json")
	w := httptest.NewRecorder()

	respondAuthError(w, req, http.StatusUnauthorized, "Authentication required")

	resp := w.Result()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
	if ct := resp.Header.Get("Content-Type"); !strings.Contains(ct, "application/json") {
		t.Errorf("Content-Type = %q, want application/json", ct)
	}
	if loc := resp.Header.Get("Location"); loc != "" {
		t.Errorf("API request must not redirect, got Location: %q", loc)
	}
}
