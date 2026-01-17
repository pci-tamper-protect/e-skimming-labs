package provider

import (
	"fmt"
	"strings"
)

// DynamicConfig represents the Traefik dynamic configuration
type DynamicConfig struct {
	HTTP HTTPConfig `yaml:"http"`
}

// HTTPConfig represents HTTP-level configuration
type HTTPConfig struct {
	Routers     map[string]RouterConfig     `yaml:"routers"`
	Services    map[string]ServiceConfig    `yaml:"services"`
	Middlewares map[string]MiddlewareConfig `yaml:"middlewares"`
}

// MiddlewareConfig represents a Traefik middleware configuration
type MiddlewareConfig struct {
	Headers *HeadersConfig `yaml:"headers,omitempty"`
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

// headersConfigAlias is used to avoid infinite recursion in MarshalYAML
type headersConfigAlias HeadersConfig

// MarshalYAML implements yaml.Marshaler to sanitize tokens when serializing
func (h *HeadersConfig) MarshalYAML() (interface{}, error) {
	if h == nil || h.CustomRequestHeaders == nil {
		return (*headersConfigAlias)(h), nil
	}

	// Return sanitized headers for YAML serialization using alias type
	// to avoid triggering MarshalYAML recursively
	return &headersConfigAlias{
		CustomRequestHeaders: sanitizeHeadersForLogging(h.CustomRequestHeaders),
		ForwardedHeaders:     h.ForwardedHeaders,
	}, nil
}

// NewDynamicConfig creates a new dynamic configuration
func NewDynamicConfig() *DynamicConfig {
	return &DynamicConfig{
		HTTP: HTTPConfig{
			Routers:     make(map[string]RouterConfig),
			Services:    make(map[string]ServiceConfig),
			Middlewares: make(map[string]MiddlewareConfig),
		},
	}
}

// AddRouter adds a router to the configuration
func (c *DynamicConfig) AddRouter(name string, config RouterConfig) {
	c.HTTP.Routers[name] = config
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
	mw := MiddlewareConfig{
		Headers: &HeadersConfig{
			CustomRequestHeaders: make(map[string]string),
		},
	}

	if token != "" {
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
	} else {
		// Don't set invalid token - let service return 401 naturally
		// This allows proper error handling
		fmt.Printf("[ConfigBuilder] ⚠️  Created auth middleware '%s' WITHOUT token (will not set X-Serverless-Authorization header)\n", name)
	}

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
