package gcp

import (
	"testing"
	"time"
)

func TestTokenManager_CacheStats(t *testing.T) {
	tm := NewTokenManager()

	// Initially empty
	total, expired := tm.CacheStats()
	if total != 0 {
		t.Errorf("Expected 0 tokens, got %d", total)
	}

	// Add a fresh token
	tm.cache["https://test-service.run.app"] = &CachedToken{
		Token:     "test-token",
		ExpiresAt: time.Now().Add(1 * time.Hour),
	}

	total, expired = tm.CacheStats()
	if total != 1 {
		t.Errorf("Expected 1 token, got %d", total)
	}
	if expired != 0 {
		t.Errorf("Expected 0 expired tokens, got %d", expired)
	}

	// Add an expired token
	tm.cache["https://expired-service.run.app"] = &CachedToken{
		Token:     "expired-token",
		ExpiresAt: time.Now().Add(-1 * time.Hour),
	}

	total, expired = tm.CacheStats()
	if total != 2 {
		t.Errorf("Expected 2 tokens, got %d", total)
	}
	if expired != 1 {
		t.Errorf("Expected 1 expired token, got %d", expired)
	}
}

func TestTokenManager_ClearCache(t *testing.T) {
	tm := NewTokenManager()

	// Add some tokens
	tm.cache["https://service1.run.app"] = &CachedToken{
		Token:     "token1",
		ExpiresAt: time.Now().Add(1 * time.Hour),
	}
	tm.cache["https://service2.run.app"] = &CachedToken{
		Token:     "token2",
		ExpiresAt: time.Now().Add(1 * time.Hour),
	}

	total, _ := tm.CacheStats()
	if total != 2 {
		t.Errorf("Expected 2 tokens before clear, got %d", total)
	}

	// Clear cache
	tm.ClearCache()

	total, _ = tm.CacheStats()
	if total != 0 {
		t.Errorf("Expected 0 tokens after clear, got %d", total)
	}
}

// Note: Testing fetchFromMetadata requires mocking the metadata server
// or running in a GCP environment. Integration tests should cover this.
