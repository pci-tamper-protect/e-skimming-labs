package gcp

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"google.golang.org/api/idtoken"
)

// TokenManager manages GCP identity tokens with caching and refresh
type TokenManager struct {
	cache           map[string]*CachedToken
	mu              sync.RWMutex
	devMode         bool // Use ADC in local development
	metadataChecked bool // Have we checked if metadata server is available?
	hasMetadata     bool // Is metadata server available?
}

// CachedToken represents a cached identity token with expiry
type CachedToken struct {
	Token     string
	ExpiresAt time.Time
}

// NewTokenManager creates a new token manager
func NewTokenManager() *TokenManager {
	// Auto-detect development mode
	devMode := os.Getenv("CLOUDRUN_PROVIDER_DEV_MODE") == "true" ||
		os.Getenv("K_SERVICE") == "" // K_SERVICE is set in Cloud Run

	return &TokenManager{
		cache:   make(map[string]*CachedToken),
		devMode: devMode,
	}
}

// GetToken gets an identity token for the given audience (service URL)
// Returns cached token if valid, otherwise fetches new token
// Uses metadata server in GCP, falls back to ADC in local development
func (tm *TokenManager) GetToken(audience string) (string, error) {
	// Check cache first
	tm.mu.RLock()
	cached, ok := tm.cache[audience]
	tm.mu.RUnlock()

	if ok && time.Now().Before(cached.ExpiresAt) {
		return cached.Token, nil
	}

	// Fetch new token
	var token string
	var err error

	// Try metadata server first (works in Cloud Run/GCE/GKE)
	if !tm.metadataChecked || tm.hasMetadata {
		token, err = tm.fetchFromMetadata(audience)
		if err != nil {
			// Check if it's a "no such host" error (running locally)
			if strings.Contains(err.Error(), "no such host") ||
				strings.Contains(err.Error(), "lookup metadata.google.internal") {
				tm.mu.Lock()
				tm.metadataChecked = true
				tm.hasMetadata = false
				tm.mu.Unlock()

				// Fall back to ADC in development mode
				if tm.devMode {
					return tm.fetchFromADC(audience)
				}
				return "", fmt.Errorf("metadata server not available (running locally?): use CLOUDRUN_PROVIDER_DEV_MODE=true and gcloud auth application-default login")
			}
			return "", err
		}

		// Metadata server worked
		tm.mu.Lock()
		tm.metadataChecked = true
		tm.hasMetadata = true
		tm.mu.Unlock()
	} else if tm.devMode {
		// Metadata server not available, use ADC
		token, err = tm.fetchFromADC(audience)
		if err != nil {
			return "", err
		}
	} else {
		return "", fmt.Errorf("metadata server not available and dev mode disabled")
	}

	// Cache token (GCP tokens expire after 1 hour)
	// Refresh 5 minutes before expiry to avoid edge cases
	tm.mu.Lock()
	tm.cache[audience] = &CachedToken{
		Token:     token,
		ExpiresAt: time.Now().Add(55 * time.Minute),
	}
	tm.mu.Unlock()

	return token, nil
}

// fetchFromMetadata fetches an identity token from the GCP metadata server
// Extracted from cmd/generate-routes/main.go:509-543
func (tm *TokenManager) fetchFromMetadata(audience string) (string, error) {
	// URL-encode the audience
	encodedAudience := strings.ReplaceAll(strings.ReplaceAll(audience, ":", "%3A"), "/", "%2F")
	url := fmt.Sprintf(
		"http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=%s",
		encodedAudience,
	)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Metadata-Flavor", "Google")

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to fetch token from metadata server: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("metadata server returned %d: %s", resp.StatusCode, string(body))
	}

	token, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read token: %w", err)
	}

	tokenStr := strings.TrimSpace(string(token))
	if !strings.HasPrefix(tokenStr, "eyJ") {
		return "", fmt.Errorf("token doesn't look valid (doesn't start with eyJ)")
	}

	return tokenStr, nil
}

// fetchFromADC fetches an identity token using Application Default Credentials
// This is used for local development when metadata server is not available
func (tm *TokenManager) fetchFromADC(audience string) (string, error) {
	ctx := context.Background()

	// Use idtoken package to create token source with ADC
	tokenSource, err := idtoken.NewTokenSource(ctx, audience)
	if err != nil {
		return "", fmt.Errorf("failed to create token source with ADC (did you run 'gcloud auth application-default login'?): %w", err)
	}

	token, err := tokenSource.Token()
	if err != nil {
		return "", fmt.Errorf("failed to fetch token from ADC: %w", err)
	}

	if token.AccessToken == "" {
		return "", fmt.Errorf("ADC returned empty token")
	}

	return token.AccessToken, nil
}

// IsDevMode returns true if running in development mode
func (tm *TokenManager) IsDevMode() bool {
	return tm.devMode
}

// HasMetadataServer returns true if metadata server is available
func (tm *TokenManager) HasMetadataServer() bool {
	tm.mu.RLock()
	defer tm.mu.RUnlock()
	return tm.hasMetadata
}

// ClearCache clears all cached tokens
func (tm *TokenManager) ClearCache() {
	tm.mu.Lock()
	defer tm.mu.Unlock()
	tm.cache = make(map[string]*CachedToken)
}

// CacheStats returns cache statistics for monitoring
func (tm *TokenManager) CacheStats() (total int, expired int) {
	tm.mu.RLock()
	defer tm.mu.RUnlock()

	total = len(tm.cache)
	now := time.Now()
	for _, cached := range tm.cache {
		if now.After(cached.ExpiresAt) {
			expired++
		}
	}
	return total, expired
}
