package provider

import (
	"fmt"
	"strings"
)

// DynamicConfig represents the Traefik dynamic configuration
type DynamicConfig struct {
	HTTP          HTTPConfig        `yaml:"http"`
	routerSources map[string]string `yaml:"-"` // Internal: tracks which service defined each router (not serialized)
}

// HTTPConfig represents HTTP-level configuration
type HTTPConfig struct {
	Routers     map[string]RouterConfig     `yaml:"routers,omitempty"`
	Services    map[string]ServiceConfig    `yaml:"services,omitempty"`
	Middlewares map[string]MiddlewareConfig `yaml:"middlewares,omitempty"`
}

// MiddlewareConfig represents a Traefik middleware configuration
type MiddlewareConfig struct {
	Headers     *HeadersConfig     `yaml:"headers,omitempty"`
	ForwardAuth *ForwardAuthConfig `yaml:"forwardAuth,omitempty"`
}

// ForwardAuthConfig represents forwardAuth middleware configuration
// Used for user JWT validation via home-index service
type ForwardAuthConfig struct {
	Address             string   `yaml:"address"`
	TrustForwardHeader  bool     `yaml:"trustForwardHeader,omitempty"`
	AuthResponseHeaders []string `yaml:"authResponseHeaders,omitempty"`
	AuthRequestHeaders  []string `yaml:"authRequestHeaders,omitempty"`
}

// HeadersConfig represents headers middleware configuration
type HeadersConfig struct {
	CustomRequestHeaders map[string]string        `yaml:"customRequestHeaders,omitempty"`
	ForwardedHeaders     *ForwardedHeadersConfig `yaml:"forwardedHeaders,omitempty"`
}

// ForwardedHeadersConfig represents forwarded headers configuration within Headers middleware
type ForwardedHeadersConfig struct {
	Insecure  bool     `yaml:"insecure,omitempty"`
	TrustedIPs []string `yaml:"trustedIPs,omitempty"`
}

// NOTE: We intentionally do NOT implement MarshalYAML for HeadersConfig
// The full tokens must be written to the routes.yml file for Traefik to use them.
// Token sanitization should only be done for logging purposes, not for the actual config file.
// See sanitizeHeadersForLogging() for log-safe token display.

// NewDynamicConfig creates a new dynamic configuration
func NewDynamicConfig() *DynamicConfig {
	return &DynamicConfig{
		HTTP: HTTPConfig{
			Routers:     make(map[string]RouterConfig),
			Services:    make(map[string]ServiceConfig),
			Middlewares: make(map[string]MiddlewareConfig),
		},
		routerSources: make(map[string]string),
	}
}

// routerSources tracks which Cloud Run service defined each router
// This is used to resolve conflicts when multiple services define the same router
// Key: router name, Value: Cloud Run service name that defined it
// This field is not serialized to YAML
type routerSourceTracker struct {
	sources map[string]string
}

// DynamicConfig with router source tracking (internal field, not serialized)
// routerSources is added to DynamicConfig struct below

// AddRouter adds a router to the configuration
// If a router with the same name already exists, it will be replaced only if
// the new source is a "dedicated" service for that router (e.g., lab1-c2-stg for lab1-c2 router)
func (c *DynamicConfig) AddRouter(name string, config RouterConfig) {
	c.HTTP.Routers[name] = config
}

// AddRouterWithSource adds a router with source tracking for conflict resolution
// sourceName is the Cloud Run service name that defines this router
func (c *DynamicConfig) AddRouterWithSource(name string, config RouterConfig, sourceName string) {
	existingSource, exists := c.routerSources[name]
	
	if exists {
		// Check if the new source is more specific/dedicated for this router
		// A dedicated service name contains the router name (e.g., "lab1-c2-stg" for "lab1-c2")
		newIsDedicated := isDedicatedService(name, sourceName)
		existingIsDedicated := isDedicatedService(name, existingSource)
		
		// Only replace if:
		// 1. New source is dedicated and existing is not, OR
		// 2. Both are dedicated (or both are not) - last one wins
		if existingIsDedicated && !newIsDedicated {
			// Keep existing - it's from a dedicated service
			return
		}
	}
	
	c.HTTP.Routers[name] = config
	c.routerSources[name] = sourceName
}

// isDedicatedService checks if a Cloud Run service is dedicated to a specific router
// e.g., "lab1-c2-stg" is dedicated to "lab1-c2" router
// e.g., "lab-01-basic-magecart-stg" is NOT dedicated to "lab1-c2" router
func isDedicatedService(routerName, serviceName string) bool {
	// Normalize router name: lab1-c2 -> lab1-c2
	// Normalize service name: lab1-c2-stg -> lab1-c2, lab-01-basic-magecart-stg -> lab-01-basic-magecart
	
	// Remove common suffixes like -stg, -prd, -dev
	normalizedService := serviceName
	for _, suffix := range []string{"-stg", "-prd", "-dev", "-staging", "-production"} {
		normalizedService = strings.TrimSuffix(normalizedService, suffix)
	}
	
	// Check if the normalized service name matches or contains the router name
	// lab1-c2 matches lab1-c2-stg (normalized: lab1-c2)
	// lab1-c2 does NOT match lab-01-basic-magecart-stg (normalized: lab-01-basic-magecart)
	if normalizedService == routerName {
		return true
	}
	
	// Also check with hyphens normalized (lab1-c2 vs lab1c2)
	normalizedRouter := strings.ReplaceAll(routerName, "-", "")
	normalizedServiceNoHyphen := strings.ReplaceAll(normalizedService, "-", "")
	
	return normalizedServiceNoHyphen == normalizedRouter
}

// AddService adds a service to the configuration
func (c *DynamicConfig) AddService(name string, config ServiceConfig) {
	c.HTTP.Services[name] = config
}

// truncateToken truncates a token to show first 20 and last 20 characters for security
func truncateToken(token string) string {
	if len(token) <= 40 {
		return token // Too short to truncate meaningfully
	}
	return token[:20] + "..." + token[len(token)-20:]
}

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

// sanitizeHeadersForLogging creates a copy of headers with sensitive values sanitized
func sanitizeHeadersForLogging(headers map[string]string) map[string]string {
	sanitized := make(map[string]string)
	for k, v := range headers {
		// Truncate tokens in Authorization and X-Serverless-Authorization headers
		if k == "Authorization" || k == "X-Serverless-Authorization" {
			if strings.HasPrefix(v, "Bearer ") {
				token := strings.TrimPrefix(v, "Bearer ")
				sanitized[k] = "Bearer " + truncateToken(token)
			} else {
				sanitized[k] = truncateToken(v)
			}
		} else if k == "X-User-Email" {
			// Sanitize email: show first 2 chars + "@" + domain
			// Example: "abraham@example.com" -> "ab@example.com"
			sanitized[k] = sanitizeEmail(v)
		} else {
			// X-User-Id and other headers: show full value (no sanitization)
			sanitized[k] = v
		}
	}
	return sanitized
}

// AddAuthMiddleware adds an authentication middleware with token
// Uses X-Serverless-Authorization header for service-to-service auth to avoid conflicts
// with user's Authorization header (Firebase token).
//
// According to Cloud Run docs:
// https://docs.cloud.google.com/run/docs/authenticating/service-to-service
// Cloud Run accepts identity tokens in either:
// - Authorization: Bearer ID_TOKEN header, OR
// - X-Serverless-Authorization: Bearer ID_TOKEN header
//
// Using X-Serverless-Authorization allows:
// - User's Authorization header (Firebase token) to pass through unchanged
// - Service-to-service auth via X-Serverless-Authorization
// - No header conflicts or middleware ordering concerns
func (c *DynamicConfig) AddAuthMiddleware(name, token string) {
	// Skip creating middleware if token is empty
	// Empty headers: {} causes Traefik YAML parsing errors: "headers cannot be a standalone element"
	if token == "" {
		fmt.Printf("[ConfigBuilder] ⚠️  Skipping auth middleware '%s' (no token provided)\n", name)
		return
	}

	mw := MiddlewareConfig{
		Headers: &HeadersConfig{
			CustomRequestHeaders: make(map[string]string),
		},
	}

	// Use X-Serverless-Authorization to avoid conflicts with user's Authorization header
	// Cloud Run will check this header for service-to-service authentication
	// If both Authorization and X-Serverless-Authorization are present, Cloud Run
	// only checks X-Serverless-Authorization (per Cloud Run docs)
	mw.Headers.CustomRequestHeaders["X-Serverless-Authorization"] = fmt.Sprintf("Bearer %s", token)

	// Log successful middleware creation with token info (truncated for security)
	tokenLen := len(token)
	tokenPreview := truncateToken(token)
	fmt.Printf("[ConfigBuilder] ✅ Created auth middleware '%s' with X-Serverless-Authorization header (token length: %d, preview: %s)\n",
		name, tokenLen, tokenPreview)

	c.HTTP.Middlewares[name] = mw
}

// GetSanitizedMiddlewareForLogging returns a sanitized version of a middleware for logging
// This truncates tokens in headers to prevent full tokens from appearing in logs
func (c *DynamicConfig) GetSanitizedMiddlewareForLogging(name string) *MiddlewareConfig {
	mw, exists := c.HTTP.Middlewares[name]
	if !exists {
		return nil
	}

	// Create a copy with sanitized headers
	sanitized := &MiddlewareConfig{}
	if mw.Headers != nil {
		sanitized.Headers = &HeadersConfig{
			CustomRequestHeaders: sanitizeHeadersForLogging(mw.Headers.CustomRequestHeaders),
		}
	}

	return sanitized
}

// AddTraefikInternalRouters adds Traefik API and Dashboard routers
func (c *DynamicConfig) AddTraefikInternalRouters() {
	// Traefik API
	c.HTTP.Routers["traefik-api"] = RouterConfig{
		Rule:        "PathPrefix(`/api/http`) || PathPrefix(`/api/rawdata`) || PathPrefix(`/api/overview`) || Path(`/api/version`)",
		Service:     "api@internal",
		Priority:    1000,
		EntryPoints: []string{"web"},
	}

	// Traefik Dashboard
	c.HTTP.Routers["traefik-dashboard"] = RouterConfig{
		Rule:        "PathPrefix(`/dashboard`)",
		Service:     "api@internal",
		Priority:    1000,
		EntryPoints: []string{"web"},
	}
}

// AddForwardAuthMiddleware adds a forwardAuth middleware for user JWT validation
// This middleware forwards auth checks to the home-index service
func (c *DynamicConfig) AddForwardAuthMiddleware(name, homeIndexURL string) {
	if homeIndexURL == "" {
		fmt.Printf("[ConfigBuilder] ⚠️  Skipping forwardAuth middleware '%s' (no home-index URL provided)\n", name)
		return
	}

	mw := MiddlewareConfig{
		ForwardAuth: &ForwardAuthConfig{
			Address:            fmt.Sprintf("%s/api/auth/check", homeIndexURL),
			TrustForwardHeader: true,
			AuthResponseHeaders: []string{
				"X-User-Id",
				"X-User-Email",
				"X-Authorization",
			},
			AuthRequestHeaders: []string{
				"Authorization",
				"Cookie",
				"X-Forwarded-For",
				"X-Forwarded-Host",
			},
		},
	}

	fmt.Printf("[ConfigBuilder] ✅ Created forwardAuth middleware '%s' with address: %s/api/auth/check\n",
		name, homeIndexURL)

	c.HTTP.Middlewares[name] = mw
}
