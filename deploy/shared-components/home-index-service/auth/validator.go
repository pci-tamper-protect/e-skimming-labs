package auth

import (
	"context"
	"fmt"
	"log"
	"time"

	"firebase.google.com/go/v4/auth"
	"firebase.google.com/go/v4"
	"google.golang.org/api/option"
)

// TokenValidator handles Firebase token validation
type TokenValidator struct {
	projectID      string
	authClient     *auth.Client
	enabled        bool
	requireAuth    bool
	mainAppURL     string
	cache          map[string]*TokenInfo
	cacheExpiry    time.Duration
	lastCacheClean time.Time
}

// TokenInfo contains validated token information
type TokenInfo struct {
	UserID    string
	Email     string
	EmailVerified bool
	ExpiresAt time.Time
	ValidatedAt time.Time
}

// Config holds authentication configuration
type Config struct {
	Enabled         bool
	RequireAuth     bool
	ProjectID       string
	CredentialsJSON string  // Service account JSON as string (from FIREBASE_API_KEY env var)
	MainAppURL      string  // Main app URL for redirects (e.g., https://app.pcioasis.com)
}

// NewTokenValidator creates a new token validator instance
func NewTokenValidator(config Config) (*TokenValidator, error) {
	if !config.Enabled {
		log.Println("🔓 Authentication disabled")
		return &TokenValidator{
			enabled: false,
		}, nil
	}

	if config.ProjectID == "" {
		return nil, fmt.Errorf("FIREBASE_PROJECT_ID is required when authentication is enabled")
	}

	log.Printf("🔐 Initializing Firebase token validator for project: %s", config.ProjectID)

	ctx := context.Background()
	var opts []option.ClientOption

	// Use credentials from environment variable (JSON string)
	if config.CredentialsJSON != "" {
		log.Printf("🔑 Loading Firebase credentials from environment variable")
		opts = append(opts, option.WithCredentialsJSON([]byte(config.CredentialsJSON)))
	} else {
		log.Printf("⚠️ No credentials provided, using application default credentials")
	}

	// Initialize Firebase app
	app, err := firebase.NewApp(ctx, &firebase.Config{
		ProjectID: config.ProjectID,
	}, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize Firebase app: %w", err)
	}

	// Get Auth client
	authClient, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get Auth client: %w", err)
	}

	tv := &TokenValidator{
		projectID:      config.ProjectID,
		authClient:     authClient,
		enabled:        config.Enabled,
		requireAuth:    config.RequireAuth,
		mainAppURL:     config.MainAppURL,
		cache:          make(map[string]*TokenInfo),
		cacheExpiry:    5 * time.Minute, // Cache tokens for 5 minutes
		lastCacheClean: time.Now(),
	}

	log.Printf("✅ Token validator initialized (requireAuth: %v)", config.RequireAuth)
	return tv, nil
}

// ValidateToken validates a Firebase ID token and returns user information
func (tv *TokenValidator) ValidateToken(ctx context.Context, token string) (*TokenInfo, error) {
	if !tv.enabled {
		// Auth disabled - allow all requests
		return nil, nil
	}

	if token == "" {
		if tv.requireAuth {
			return nil, fmt.Errorf("authentication required but no token provided")
		}
		return nil, nil // Auth optional, no token is OK
	}

	// Check cache first
	if cached, ok := tv.cache[token]; ok {
		if time.Now().Before(cached.ExpiresAt) {
			log.Printf("✅ Token validated from cache (user: %s)", cached.Email)
			return cached, nil
		}
		// Cache expired, remove it
		delete(tv.cache, token)
	}

	// Clean cache periodically
	if time.Since(tv.lastCacheClean) > 10*time.Minute {
		tv.cleanCache()
	}

	// Validate token with Firebase Admin SDK
	tokenResult, err := tv.authClient.VerifyIDToken(ctx, token)
	if err != nil {
		log.Printf("❌ Token validation failed: %v", err)
		return nil, fmt.Errorf("invalid token: %w", err)
	}

	// Extract user information from token claims
	claims := tokenResult.Claims
	userID := tokenResult.UID
	email, _ := claims["email"].(string)
	emailVerified, _ := claims["email_verified"].(bool)
	exp, _ := claims["exp"].(float64)

	expiresAt := time.Unix(int64(exp), 0)
	validatedAt := time.Now()

	tokenInfo := &TokenInfo{
		UserID:        userID,
		Email:         email,
		EmailVerified: emailVerified,
		ExpiresAt:     expiresAt,
		ValidatedAt:   validatedAt,
	}

	// Cache the token info
	tv.cache[token] = tokenInfo

	log.Printf("✅ Token validated successfully (user: %s, email: %s)", userID, email)
	return tokenInfo, nil
}

// cleanCache removes expired entries from the cache
func (tv *TokenValidator) cleanCache() {
	now := time.Now()
	for token, info := range tv.cache {
		if now.After(info.ExpiresAt) {
			delete(tv.cache, token)
		}
	}
	tv.lastCacheClean = now
}

// IsEnabled returns whether authentication is enabled
func (tv *TokenValidator) IsEnabled() bool {
	return tv.enabled
}

// IsRequired returns whether authentication is required
func (tv *TokenValidator) IsRequired() bool {
	return tv.requireAuth
}

// GetProjectID returns the Firebase project ID
func (tv *TokenValidator) GetProjectID() string {
	return tv.projectID
}

// GetMainAppURL returns the main app URL for redirects
func (tv *TokenValidator) GetMainAppURL() string {
	return tv.mainAppURL
}
