package provider

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/pci-tamper-protect/traefik-cloudrun-provider/internal/gcp"
	"github.com/pci-tamper-protect/traefik-cloudrun-provider/internal/logging"
	run "google.golang.org/api/run/v1"
)

// Config represents the provider configuration
type Config struct {
	// GCP Configuration
	ProjectIDs   []string      // List of GCP project IDs to monitor
	Region       string        // GCP region (e.g., "us-central1")
	PollInterval time.Duration // How often to poll Cloud Run API

	// Optional: Eventarc configuration (future)
	EventarcEnabled bool
	EventarcTopic   string

	// Token cache settings
	TokenRefreshBefore time.Duration // Refresh tokens this long before expiry
}

// Provider implements the Traefik provider interface for Cloud Run
type Provider struct {
	config       *Config
	runService   *run.APIService
	tokenManager *gcp.TokenManager
	logger       *logging.Logger
	stopChan     chan struct{}
}

// New creates a new Cloud Run provider
func New(config *Config) (*Provider, error) {
	p, err := newProvider(config)
	if err != nil {
		return nil, err
	}

	// Initialize Cloud Run client — requires GCP credentials.
	ctx := context.Background()
	runService, err := run.NewService(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create Cloud Run service: %w", err)
	}
	p.logger.Debug("Cloud Run API client initialized")
	p.runService = runService

	return p, nil
}

// newProvider builds a Provider without initializing the Cloud Run API client.
// Used by New (which adds the real client) and by tests that don't exercise
// service discovery and therefore don't need GCP credentials.
func newProvider(config *Config) (*Provider, error) {
	if config == nil {
		return nil, fmt.Errorf("config cannot be nil")
	}

	// Validate configuration
	if len(config.ProjectIDs) == 0 {
		return nil, fmt.Errorf("at least one project ID must be specified")
	}
	if config.Region == "" {
		return nil, fmt.Errorf("region must be specified")
	}
	if config.PollInterval == 0 {
		config.PollInterval = 30 * time.Second
	}

	// Setup logger
	logLevel := logging.LevelInfo
	if level := os.Getenv("LOG_LEVEL"); level != "" {
		if parsed, err := logging.ParseLevel(level); err == nil {
			logLevel = parsed
		}
	}

	logFormat := logging.FormatText
	if format := os.Getenv("LOG_FORMAT"); format != "" {
		if parsed, err := logging.ParseFormat(format); err == nil {
			logFormat = parsed
		}
	}

	logger := logging.New(&logging.Config{
		Level:  logLevel,
		Format: logFormat,
		Output: os.Stdout,
	}).WithPrefix("CloudRunProvider")

	logger.Info("Initializing Cloud Run provider",
		logging.Any("projects", config.ProjectIDs),
		logging.String("region", config.Region),
		logging.Duration("pollInterval", config.PollInterval),
	)

	tokenManager := gcp.NewTokenManager()
	if tokenManager.IsDevMode() {
		logger.Warn("Running in development mode - will use ADC for tokens if metadata server unavailable")
	}

	return &Provider{
		config:       config,
		tokenManager: tokenManager,
		logger:       logger,
		stopChan:     make(chan struct{}),
	}, nil
}

// Start begins polling for Cloud Run services and generating configurations
func (p *Provider) Start(configChan chan<- *DynamicConfig) error {
	p.logger.Info("Starting provider", logging.Duration("pollInterval", p.config.PollInterval))

	// Generate initial configuration
	p.logger.Debug("Generating initial configuration")
	if err := p.updateConfig(configChan); err != nil {
		return fmt.Errorf("failed to generate initial config: %w", err)
	}

	p.logger.Info("Initial configuration generated successfully")

	// Start polling loop
	go p.pollLoop(configChan)

	return nil
}

// Stop stops the provider
func (p *Provider) Stop() error {
	close(p.stopChan)
	p.logger.Info("Provider stopped")
	return nil
}

// RunOnce discovers services and generates configuration once, without starting a polling goroutine.
// Use this in daemon mode where the caller manages the polling interval.
func (p *Provider) RunOnce(configChan chan<- *DynamicConfig) error {
	return p.updateConfig(configChan)
}

// pollLoop polls Cloud Run API at configured intervals
func (p *Provider) pollLoop(configChan chan<- *DynamicConfig) {
	ticker := time.NewTicker(p.config.PollInterval)
	defer ticker.Stop()

	pollCount := 0
	for {
		select {
		case <-ticker.C:
			pollCount++
			p.logger.Debug("Polling for configuration updates", logging.Int("pollCount", pollCount))

			if err := p.updateConfig(configChan); err != nil {
				p.logger.Error("Failed to update configuration", logging.Error(err))
			}
		case <-p.stopChan:
			p.logger.Debug("Stopping poll loop")
			return
		}
	}
}

// updateConfig discovers services and generates Traefik configuration
//
//nolint:gocyclo
func (p *Provider) updateConfig(configChan chan<- *DynamicConfig) error {
	startTime := time.Now()
	p.logger.Info("Starting service discovery...",
		logging.GetCodeField(logging.CodeServiceDiscoveryStarted),
	)
	config := NewDynamicConfig()

	totalServices := 0

	// Track home-index URL for user auth middleware generation
	var homeIndexURL string

	// Discover services from all configured projects
	for _, projectID := range p.config.ProjectIDs {
		p.logger.Info("Listing Cloud Run services in project",
			logging.String("project", projectID),
			logging.String("region", p.config.Region),
		)

		services, err := p.listServices(p.runService, projectID, p.config.Region)
		if err != nil {
			p.logger.Error("Failed to list services in project",
				logging.GetCodeField(logging.CodeServiceDiscoveryError),
				logging.String("project", projectID),
				logging.Error(err),
			)
			continue
		}

		totalServices += len(services)
		p.logger.Info("Discovered services",
			logging.GetCodeField(logging.CodeServiceDiscoverySuccess),
			logging.String("project", projectID),
			logging.Int("count", len(services)),
		)

		// Filter services with traefik_enable=true
		traefikEnabledCount := 0
		for _, service := range services {
			// Check if service has traefik_enable=true label
			if enabled, ok := service.Labels["traefik_enable"]; ok && enabled == labelValueTrue {
				traefikEnabledCount++
				p.logger.Info("Processing Traefik-enabled service",
					logging.GetCodeField(logging.CodeServiceProcessingStarted),
					logging.String("service", service.Name),
					logging.String("project", projectID),
				)
				if err := p.processService(service, config); err != nil {
					p.logger.Error("Failed to process service",
						logging.GetCodeField(logging.CodeServiceProcessingError),
						logging.String("service", service.Name),
						logging.String("project", projectID),
						logging.Error(err),
					)
					continue
				}
				p.logger.Info("Service processed successfully",
					logging.GetCodeField(logging.CodeServiceProcessingSuccess),
					logging.String("service", service.Name),
				)

				// Track home-index URL for user auth middleware
				if strings.Contains(service.Name, "home-index") && service.URL != "" {
					homeIndexURL = service.URL
					p.logger.Info("Found home-index service for user auth",
						logging.String("url", homeIndexURL),
					)
				}
			} else {
				p.logger.Debug("Skipping service (traefik_enable != true)",
					logging.GetCodeField(logging.CodeServiceSkipped),
					logging.String("service", service.Name),
				)
			}
		}

		if traefikEnabledCount == 0 {
			p.logger.Warn("No Traefik-enabled services found in project",
				logging.GetCodeField(logging.CodeServiceDiscoveryNoServices),
				logging.String("project", projectID),
				logging.Int("totalServices", len(services)),
			)
		} else {
			p.logger.Info("Processed Traefik-enabled services",
				logging.GetCodeField(logging.CodeServiceDiscoverySuccess),
				logging.String("project", projectID),
				logging.Int("enabledCount", traefikEnabledCount),
				logging.Int("totalServices", len(services)),
			)
		}
	}

	// Fallback: use HOME_INDEX_URL env when discovery didn't find home-index
	// (e.g. home-index in labs-home-* project, provider SA lacks run.viewer, or service not yet deployed)
	if homeIndexURL == "" {
		homeIndexURL = strings.TrimSpace(os.Getenv("HOME_INDEX_URL"))
		if homeIndexURL != "" {
			p.logger.Info("Using HOME_INDEX_URL from env (discovery did not find home-index)",
				logging.String("homeIndexURL", homeIndexURL),
			)
		}
	}

	// When using HOME_INDEX_URL fallback, add home-index service and routers if not already discovered
	// Without this, routes.yml would have no route for "/" and labs.pcioasis.com would return 404
	if homeIndexURL != "" {
		if _, hasService := config.HTTP.Services["home-index"]; !hasService {
			p.logger.Info("Adding home-index service and routers from HOME_INDEX_URL (not discovered from Cloud Run)")
			serviceToken, err := p.tokenManager.GetToken(homeIndexURL)
			if err != nil {
				p.logger.Warn("Failed to get token for HOME_INDEX_URL fallback",
					logging.String("homeIndexURL", homeIndexURL),
					logging.Error(err),
				)
			}
			if serviceToken != "" {
				config.AddAuthMiddleware("home-index-auth", serviceToken)
			}
			routerMiddlewares := []string{"forwarded-headers@file"}
			if serviceToken != "" {
				routerMiddlewares = append([]string{"home-index-auth"}, routerMiddlewares...)
			}
			routerMiddlewares = append(routerMiddlewares, "retry-cold-start@file")
			config.AddService("home-index", ServiceConfig{
				LoadBalancer: LoadBalancerConfig{
					Servers:        []ServerConfig{{URL: homeIndexURL}},
					PassHostHeader: false,
				},
			})
			config.AddRouter("home-index", RouterConfig{
				Rule:        "PathPrefix(`/`)",
				Service:     "home-index",
				Priority:    1,
				EntryPoints: []string{"web"},
				Middlewares: routerMiddlewares,
			})
			config.AddRouter("home-index-signin", RouterConfig{
				Rule:        "Path(`/sign-in`) || Path(`/sign-up`)",
				Service:     "home-index",
				Priority:    100,
				EntryPoints: []string{"web"},
				Middlewares: []string{"signin-headers@file", "forwarded-headers@file", "retry-cold-start@file"},
			})
		}
	}

	// Note: Common middlewares like forwarded-headers are defined in routes.yml
	// and loaded via the file provider, since dynamic.Headers doesn't support
	// forwarded headers configuration. The file provider is still enabled for
	// static middlewares like retry-cold-start@file and forwarded-headers@file.

	// Generate user auth middlewares if USER_AUTH_ENABLED is true
	// These forwardAuth middlewares call home-index /api/auth/check for JWT validation
	userAuthEnabled := os.Getenv("USER_AUTH_ENABLED") == labelValueTrue
	if userAuthEnabled && homeIndexURL != "" {
		p.logger.Info("USER_AUTH_ENABLED=true, generating forwardAuth middlewares",
			logging.String("homeIndexURL", homeIndexURL),
		)
		// Generate lab auth-check middlewares that point to the Cloud Run home-index URL
		config.AddForwardAuthMiddleware("lab1-auth-check", homeIndexURL)
		config.AddForwardAuthMiddleware("lab2-auth-check", homeIndexURL)
		config.AddForwardAuthMiddleware("lab3-auth-check", homeIndexURL)
		config.AddForwardAuthMiddleware("lab4-auth-check", homeIndexURL)
	} else if userAuthEnabled && homeIndexURL == "" {
		p.logger.Warn("USER_AUTH_ENABLED=true but home-index URL not found - user auth middlewares not generated")
	} else {
		p.logger.Info("USER_AUTH_ENABLED not set or false - skipping user auth middlewares")
	}

	// Add Traefik API/Dashboard routers
	p.logger.Debug("Adding Traefik internal routers (API/Dashboard)...")
	config.AddTraefikInternalRouters()

	duration := time.Since(startTime)
	p.logger.Info("Configuration generation complete",
		logging.GetCodeField(logging.CodeConfigGenerationSuccess),
		logging.Int("totalServices", totalServices),
		logging.Int("routers", len(config.HTTP.Routers)),
		logging.Int("services", len(config.HTTP.Services)),
		logging.Int("middlewares", len(config.HTTP.Middlewares)),
		logging.Duration("duration", duration),
	)

	// Send configuration to Traefik
	p.logger.Info("Sending configuration to channel...")
	configChan <- config
	p.logger.Info("Configuration sent successfully",
		logging.GetCodeField(logging.CodeConfigSentSuccess),
	)

	return nil
}

// processService processes a single Cloud Run service and adds it to the configuration
//
//nolint:gocyclo
func (p *Provider) processService(service CloudRunService, config *DynamicConfig) error {
	p.logger.Info("Processing service",
		logging.GetCodeField(logging.CodeServiceProcessingStarted),
		logging.String("name", service.Name),
		logging.String("project", service.ProjectID),
		logging.String("url", service.URL),
	)

	// Extract router configs from labels
	p.logger.Debug("Extracting router configurations from labels...")
	routerConfigs := extractRouterConfigs(service.Labels, service.Name)
	if len(routerConfigs) == 0 {
		p.logger.Warn("No router labels found for service",
			logging.GetCodeField(logging.CodeServiceProcessingError),
			logging.String("service", service.Name),
		)
		return fmt.Errorf("no router labels found")
	}

	p.logger.Info("Extracted router configurations",
		logging.String("service", service.Name),
		logging.Int("routerCount", len(routerConfigs)),
	)

	// Determine service name from labels
	serviceNameFromLabel := service.Name
	for _, router := range routerConfigs {
		if router.Service != "" {
			serviceNameFromLabel = router.Service
			break
		}
	}

	// Set service name on routers that don't have it explicitly set
	// This ensures all routers point to the correct service
	// Note: Cannot directly assign to struct field in map - must get, modify, and put back
	for routerName := range routerConfigs {
		if routerConfigs[routerName].Service == "" {
			routerConfig := routerConfigs[routerName]
			routerConfig.Service = serviceNameFromLabel
			routerConfigs[routerName] = routerConfig
		}
	}

	// Get identity token for service
	// This token will be used in Authorization header for Cloud Run service-to-service auth
	p.logger.Debug("Fetching identity token for service",
		logging.String("service", service.Name),
		logging.String("url", service.URL),
	)

	serviceToken, err := p.tokenManager.GetToken(service.URL)
	if err != nil {
		p.logger.Error("Failed to fetch identity token for service",
			logging.GetCodeField(logging.CodeTokenFetchError),
			logging.String("service", service.Name),
			logging.String("url", service.URL),
			logging.Error(err),
		)
		// Log detailed error for debugging
		if strings.Contains(err.Error(), "metadata server") {
			p.logger.Error("Metadata server issue - check if running in Cloud Run or set CLOUDRUN_PROVIDER_DEV_MODE=true",
				logging.String("service", service.Name),
			)
		}
		if strings.Contains(err.Error(), "ADC") {
			p.logger.Error("ADC issue - run 'gcloud auth application-default login' for local development",
				logging.String("service", service.Name),
			)
		}
		// Continue without token - service will return 401
		serviceToken = ""
	} else {
		// Validate token format
		if !strings.HasPrefix(serviceToken, "eyJ") {
			previewLen := 20
			if len(serviceToken) < previewLen {
				previewLen = len(serviceToken)
			}
			p.logger.Error("Token doesn't look valid (should start with eyJ for JWT)",
				logging.GetCodeField(logging.CodeTokenInvalid),
				logging.String("service", service.Name),
				logging.String("tokenPreview", serviceToken[:previewLen]),
				logging.Int("tokenLength", len(serviceToken)),
			)
			serviceToken = ""
		} else {
			p.logger.Info("Successfully fetched identity token for service",
				logging.GetCodeField(logging.CodeTokenFetchSuccess),
				logging.String("service", service.Name),
				logging.String("url", service.URL),
				logging.Int("tokenLength", len(serviceToken)),
			)
		}
	}

	// Create auth middleware (only if token is available)
	authMiddlewareName := fmt.Sprintf("%s-auth", serviceNameFromLabel)
	authMiddlewareCreated := false
	if serviceToken != "" {
		config.AddAuthMiddleware(authMiddlewareName, serviceToken)
		authMiddlewareCreated = true
	} else {
		// Skip creating middleware if no token (avoids empty headers: {} in YAML)
		p.logger.Debug("Skipping auth middleware creation (no token)",
			logging.String("middleware", authMiddlewareName),
		)
	}

	// Add routers (with auth middleware and retry middleware)
	// USER_AUTH_ENABLED controls whether user JWT auth is required for labs
	// - When false (default): Skip auth-check middlewares (no user auth required)
	// - When true: Include auth-check middlewares (user must be authenticated)
	// Note: SKIP_AUTH_CHECK is deprecated, use USER_AUTH_ENABLED=false instead
	userAuthEnabled := os.Getenv("USER_AUTH_ENABLED") == labelValueTrue
	skipAuthCheck := os.Getenv("SKIP_AUTH_CHECK") == "true" || !userAuthEnabled

	for routerName, routerConfig := range routerConfigs {
		// Filter out auth-check middlewares if user auth is disabled
		// These middlewares use forwardAuth which requires home-index service
		if skipAuthCheck {
			filteredMiddlewares := make([]string, 0, len(routerConfig.Middlewares))
			for _, mw := range routerConfig.Middlewares {
				if !strings.Contains(mw, "auth-check") {
					filteredMiddlewares = append(filteredMiddlewares, mw)
				} else {
					p.logger.Debug("Skipping auth-check middleware (USER_AUTH_ENABLED=false)",
						logging.String("router", routerName),
						logging.String("middleware", mw))
				}
			}
			routerConfig.Middlewares = filteredMiddlewares
		}

		// Auto-inject strip-prefix middleware for lab routes if not already present
		// This ensures /lab1 requests get their prefix stripped before reaching the backend
		// Lab services expect requests at / (root), not /lab1
		stripPrefixMiddleware := getStripPrefixMiddleware(routerName, routerConfig.Rule)
		if stripPrefixMiddleware != "" {
			hasStripPrefix := false
			for _, mw := range routerConfig.Middlewares {
				if strings.Contains(mw, "strip-") && strings.Contains(mw, "-prefix") {
					hasStripPrefix = true
					break
				}
			}
			if !hasStripPrefix {
				// Add strip-prefix middleware after auth but before retry
				routerConfig.Middlewares = append(routerConfig.Middlewares, stripPrefixMiddleware)
				p.logger.Debug("Auto-injected strip-prefix middleware",
					logging.String("router", routerName),
					logging.String("middleware", stripPrefixMiddleware))
			}
		}

		// Add service auth middleware if it was created and not already present
		// Note: Middleware order doesn't matter for header conflicts since we use
		// X-Serverless-Authorization (doesn't conflict with user's Authorization header)
		if authMiddlewareCreated {
			hasServiceAuth := false
			for _, mw := range routerConfig.Middlewares {
				if mw == authMiddlewareName || mw == fmt.Sprintf("%s@file", authMiddlewareName) {
					hasServiceAuth = true
					break
				}
			}

			if !hasServiceAuth {
				// Prepend service auth middleware (runs before other middlewares)
				// This ensures service-to-service auth is set early in the request chain
				routerConfig.Middlewares = append([]string{authMiddlewareName}, routerConfig.Middlewares...)
			}
		}

		// Always add retry middleware for cold starts (at the end)
		hasRetry := false
		for _, mw := range routerConfig.Middlewares {
			if mw == "retry-cold-start@file" {
				hasRetry = true
				break
			}
		}
		if !hasRetry {
			routerConfig.Middlewares = append(routerConfig.Middlewares, "retry-cold-start@file")
		}

		// Log router configuration with middlewares (user-friendly format)
		middlewareList := strings.Join(routerConfig.Middlewares, ", ")
		if middlewareList == "" {
			middlewareList = "none"
		}

		// Check if service auth middleware is present for better debugging
		hasAuthMw := false
		for _, mw := range routerConfig.Middlewares {
			if mw == authMiddlewareName {
				hasAuthMw = true
				break
			}
		}

		p.logger.Info("Router configured",
			logging.GetCodeField(logging.CodeRouterConfigured),
			logging.String("router", routerName),
			logging.String("rule", routerConfig.Rule),
			logging.String("service", routerConfig.Service),
			logging.String("middlewares", fmt.Sprintf("[%s]", middlewareList)),
			logging.String("expectedAuthMiddleware", authMiddlewareName),
			logging.String("hasAuthMiddleware", fmt.Sprintf("%v", hasAuthMw)),
		)

		// Use AddRouterWithSource to handle conflicts when multiple services define the same router
		// Dedicated services (e.g., lab1-c2-stg for lab1-c2 router) take precedence
		config.AddRouterWithSource(routerName, routerConfig, service.Name)
	}

	// Add service definition
	serviceConfig := ServiceConfig{
		LoadBalancer: LoadBalancerConfig{
			Servers:        []ServerConfig{{URL: service.URL}},
			PassHostHeader: false,
		},
	}
	config.AddService(serviceNameFromLabel, serviceConfig)

	p.logger.Debug("Service processed successfully",
		logging.String("service", service.Name),
		logging.String("serviceName", serviceNameFromLabel),
	)

	return nil
}

// getStripPrefixMiddleware returns the appropriate strip-prefix middleware name
// for a given router based on its name and rule. Returns empty string if no
// strip-prefix middleware should be auto-injected.
//
// This function automatically injects strip-prefix middlewares for lab routes
// because lab services expect requests at / (root), not /labN.
// The middlewares must be pre-defined in the static routes.yml file.
func getStripPrefixMiddleware(routerName, _ string) string {
	// Map of router name patterns to their strip-prefix middleware
	// These middlewares are defined in e-skimming-labs/deploy/traefik/dynamic/routes.yml
	stripPrefixMap := map[string]string{
		// Lab 1 routes
		"lab1":        "strip-lab1-prefix@file",
		"lab1-static": "strip-lab1-prefix@file",
		"lab1-c2":     "strip-lab1-c2-prefix@file",
		// Lab 2 routes
		"lab2":        "strip-lab2-prefix@file",
		"lab2-main":   "strip-lab2-prefix@file",
		"lab2-static": "strip-lab2-prefix@file",
		"lab2-c2":     "strip-lab2-c2-prefix@file",
		// Lab 3 routes
		"lab3":           "strip-lab3-prefix@file",
		"lab3-main":      "strip-lab3-prefix@file",
		"lab3-static":    "strip-lab3-prefix@file",
		"lab3-extension": "strip-lab3-extension-prefix@file",
		// Lab 4 routes
		"lab4":        "strip-lab4-prefix@file",
		"lab4-main":   "strip-lab4-prefix@file",
		"lab4-static": "strip-lab4-prefix@file",
		"lab4-c2":     "strip-lab4-c2-prefix@file",
		// API routes
		"home-seo":       "strip-seo-prefix@file",
		"labs-analytics": "strip-analytics-prefix@file",
	}

	// Check for exact match first
	if middleware, ok := stripPrefixMap[routerName]; ok {
		return middleware
	}

	// Check for prefix match (e.g., "lab1-something" matches "lab1")
	// But skip if already handled by exact match above
	for prefix, middleware := range stripPrefixMap {
		if strings.HasPrefix(routerName, prefix+"-") {
			// Skip if this is a more specific route that should have its own middleware
			// (these are already in the map above)
			if strings.Contains(routerName, "-c2") || strings.Contains(routerName, "-extension") {
				continue
			}
			return middleware
		}
	}

	return ""
}
