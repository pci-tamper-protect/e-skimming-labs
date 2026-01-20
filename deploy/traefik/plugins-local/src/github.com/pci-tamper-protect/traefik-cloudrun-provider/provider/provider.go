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

	// Initialize Cloud Run client
	ctx := context.Background()
	runService, err := run.NewService(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create Cloud Run service: %w", err)
	}

	logger.Debug("Cloud Run API client initialized")

	tokenManager := gcp.NewTokenManager()
	if tokenManager.IsDevMode() {
		logger.Warn("Running in development mode - will use ADC for tokens if metadata server unavailable")
	}

	return &Provider{
		config:       config,
		runService:   runService,
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
func (p *Provider) updateConfig(configChan chan<- *DynamicConfig) error {
	startTime := time.Now()
	p.logger.Info("Starting service discovery...",
		logging.GetCodeField(logging.CodeServiceDiscoveryStarted),
	)
	config := NewDynamicConfig()

	totalServices := 0

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
			if enabled, ok := service.Labels["traefik_enable"]; ok && enabled == "true" {
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

	// Note: Common middlewares like forwarded-headers are defined in routes.yml
	// and loaded via the file provider, since dynamic.Headers doesn't support
	// forwarded headers configuration. The file provider is still enabled for
	// static middlewares like retry-cold-start@file and forwarded-headers@file.

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

	// Create auth middleware
	authMiddlewareName := fmt.Sprintf("%s-auth", serviceNameFromLabel)
	config.AddAuthMiddleware(authMiddlewareName, serviceToken)

	// Add routers (with auth middleware and retry middleware)
	for routerName, routerConfig := range routerConfigs {
		// Add service auth middleware if not already present
		// Note: Middleware order doesn't matter for header conflicts since we use
		// X-Serverless-Authorization (doesn't conflict with user's Authorization header)
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

		config.AddRouter(routerName, routerConfig)
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
