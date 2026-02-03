// Package plugin provides the Traefik plugin interface for the Cloud Run provider
package plugin

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/pci-tamper-protect/traefik-cloudrun-provider/internal/gcp"
	"github.com/pci-tamper-protect/traefik-cloudrun-provider/internal/logging"
	"github.com/pci-tamper-protect/traefik-cloudrun-provider/provider"
	"github.com/traefik/genconf/dynamic"
	run "google.golang.org/api/run/v1"
)

// Config represents the plugin configuration
type Config struct {
	// GCP Configuration
	ProjectIDs   []string      `json:"projectIDs,omitempty" yaml:"projectIDs,omitempty"`
	Region       string        `json:"region,omitempty" yaml:"region,omitempty"`
	PollInterval time.Duration `json:"pollInterval,omitempty" yaml:"pollInterval,omitempty"`

	// Token cache settings
	TokenRefreshBefore time.Duration `json:"tokenRefreshBefore,omitempty" yaml:"tokenRefreshBefore,omitempty"`
}

// CreateConfig creates the default plugin configuration
// This is called by Traefik when it discovers the plugin
func CreateConfig() *Config {
	// Log that Traefik has discovered the plugin
	// Note: Logger not available yet, so we use fmt for this critical step
	// Include code for reliable parsing
	fmt.Fprintf(os.Stderr, "[CloudRunPlugin] code=%s Plugin discovered by Traefik - CreateConfig() called\n", logging.CodeCreateConfigSuccess)

	config := &Config{
		ProjectIDs:   []string{},
		Region:       "us-central1",
		PollInterval: 30 * time.Second,
	}

	fmt.Fprintf(os.Stderr, "[CloudRunPlugin] code=%s CreateConfig() returning default configuration\n", logging.CodeCreateConfigSuccess)
	return config
}

// PluginProvider implements the Traefik plugin provider interface
type PluginProvider struct {
	name         string
	config       *Config
	runService   *run.APIService
	tokenManager *gcp.TokenManager
	logger       *logging.Logger
	stopChan     chan struct{}
}

// New creates a new plugin provider
func New(ctx context.Context, config *Config, name string) (*PluginProvider, error) {
	fmt.Fprintf(os.Stderr, "[CloudRunPlugin] 🔧 INFO: New() called by Traefik\n")

	if config == nil {
		fmt.Fprintf(os.Stderr, "[CloudRunPlugin] code=%s New() called with nil config\n", logging.CodeNewConfigNil)
		return nil, fmt.Errorf("config cannot be nil")
	}

	// Load project IDs from environment if not set in config
	if len(config.ProjectIDs) == 0 {
		primaryProject := os.Getenv("LABS_PROJECT_ID")
		if primaryProject == "" {
			fmt.Fprintf(os.Stderr, "[CloudRunPlugin] code=%s LABS_PROJECT_ID environment variable not set\n", logging.CodeNewProjectIDMissing)
			return nil, fmt.Errorf("at least one project ID must be specified (set LABS_PROJECT_ID or configure projectIDs)")
		}
		fmt.Fprintf(os.Stderr, "[CloudRunPlugin] code=%s LABS_PROJECT_ID found: %s\n", logging.CodeNewProjectIDFound, primaryProject)
		config.ProjectIDs = []string{primaryProject}

		// Add secondary project if available
		if secondaryProject := os.Getenv("HOME_PROJECT_ID"); secondaryProject != "" {
			fmt.Fprintf(os.Stderr, "[CloudRunPlugin] code=%s HOME_PROJECT_ID found: %s\n", logging.CodeNewProjectIDFound, secondaryProject)
			config.ProjectIDs = append(config.ProjectIDs, secondaryProject)
		}
	}

	// Use region from environment if not set
	if config.Region == "" {
		config.Region = os.Getenv("REGION")
		if config.Region == "" {
			config.Region = "us-central1"
		}
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
	}).WithPrefix("CloudRunPlugin")

	logger.Info("Plugin instantiated by Traefik - New() called",
		logging.GetCodeField(logging.CodeNewSuccess),
		logging.String("name", name),
		logging.Any("projects", config.ProjectIDs),
		logging.String("region", config.Region),
		logging.Duration("pollInterval", config.PollInterval),
	)

	// Initialize Cloud Run client
	logger.Info("Initializing Cloud Run API client...")
	runService, err := run.NewService(ctx)
	if err != nil {
		logger.Error("Failed to create Cloud Run service",
			logging.GetCodeField(logging.CodeNewCloudRunClientError),
			logging.Error(err),
		)
		return nil, fmt.Errorf("failed to create Cloud Run service: %w", err)
	}

	logger.Info("Cloud Run API client initialized successfully",
		logging.GetCodeField(logging.CodeNewSuccess),
	)

	logger.Info("Initializing token manager...")
	tokenManager := gcp.NewTokenManager()
	if tokenManager.IsDevMode() {
		logger.Warn("Running in development mode - will use ADC for tokens if metadata server unavailable")
	} else {
		logger.Info("Token manager initialized (production mode - using metadata server)")
	}

	logger.Info("Plugin provider created successfully",
		logging.GetCodeField(logging.CodeNewSuccess),
		logging.String("name", name),
		logging.Int("projectCount", len(config.ProjectIDs)),
	)

	provider := &PluginProvider{
		name:         name,
		config:       config,
		runService:   runService,
		tokenManager: tokenManager,
		logger:       logger,
		stopChan:     make(chan struct{}),
	}

	logger.Info("New() completed successfully, returning plugin provider",
		logging.GetCodeField(logging.CodeNewSuccess),
	)
	return provider, nil
}

// Init initializes the provider
// This is called by Traefik after New() to perform initialization
func (p *PluginProvider) Init() error {
	p.logger.Info("Init() called by Traefik",
		logging.String("name", p.name),
	)

	// Perform any initialization checks here
	// Currently no-op, but we log success/failure explicitly
	p.logger.Info("Init() completed successfully",
		logging.GetCodeField(logging.CodeInitSuccess),
	)
	return nil
}

// Provide creates and sends dynamic configuration
// This is called by Traefik to start the provider and begin generating configurations
func (p *PluginProvider) Provide(cfgChan chan<- json.Marshaler) error {
	p.logger.Info("Provide() called by Traefik",
		logging.Duration("pollInterval", p.config.PollInterval),
	)

	// Generate initial configuration
	p.logger.Info("Generating initial configuration...")
	if err := p.updateConfig(cfgChan); err != nil {
		p.logger.Error("Failed to generate initial config",
			logging.GetCodeField(logging.CodeProvideInitialConfigError),
			logging.Error(err),
		)
		return fmt.Errorf("failed to generate initial config: %w", err)
	}

	p.logger.Info("Initial configuration generated and sent to Traefik successfully",
		logging.GetCodeField(logging.CodeProvideInitialConfigSuccess),
	)

	// Start polling loop
	p.logger.Info("Starting polling loop for configuration updates...")
	go p.pollLoop(cfgChan)

	p.logger.Info("Provide() completed successfully, provider is now active",
		logging.GetCodeField(logging.CodeProvideSuccess),
	)
	return nil
}

// Stop stops the provider
func (p *PluginProvider) Stop() error {
	close(p.stopChan)
	p.logger.Info("Provider stopped")
	return nil
}

// pollLoop polls Cloud Run API at configured intervals
func (p *PluginProvider) pollLoop(cfgChan chan<- json.Marshaler) {
	ticker := time.NewTicker(p.config.PollInterval)
	defer ticker.Stop()

	pollCount := 0
	for {
		select {
		case <-ticker.C:
			pollCount++
			p.logger.Info("Polling for configuration updates",
				logging.GetCodeField(logging.CodePollStarted),
				logging.Int("pollCount", pollCount),
			)

			if err := p.updateConfig(cfgChan); err != nil {
				p.logger.Error("Failed to update configuration",
					logging.GetCodeField(logging.CodePollError),
					logging.Int("pollCount", pollCount),
					logging.Error(err),
				)
			} else {
				p.logger.Info("Configuration update completed successfully",
					logging.GetCodeField(logging.CodePollSuccess),
					logging.Int("pollCount", pollCount),
				)
			}
		case <-p.stopChan:
			p.logger.Debug("Stopping poll loop")
			return
		}
	}
}

// updateConfig discovers services and generates Traefik configuration
func (p *PluginProvider) updateConfig(cfgChan chan<- json.Marshaler) error {
	startTime := time.Now()
	p.logger.Info("Starting configuration update cycle...",
		logging.GetCodeField(logging.CodeConfigGenerationStarted),
		logging.String("timestamp", startTime.Format(time.RFC3339)),
	)

	// Create internal provider to reuse existing logic
	p.logger.Debug("Creating internal provider instance...")
	providerConfig := &provider.Config{
		ProjectIDs:   p.config.ProjectIDs,
		Region:       p.config.Region,
		PollInterval: p.config.PollInterval,
	}

	internalProvider, err := provider.New(providerConfig)
	if err != nil {
		p.logger.Error("Failed to create internal provider",
			logging.GetCodeField(logging.CodeInternalProviderError),
			logging.Error(err),
		)
		return fmt.Errorf("failed to create internal provider: %w", err)
	}
	p.logger.Info("Internal provider created",
		logging.GetCodeField(logging.CodeInternalProviderCreated),
	)

	// Generate configuration using internal provider
	p.logger.Debug("Starting internal provider to discover services...")
	internalConfigChan := make(chan *provider.DynamicConfig, 1)
	if err := internalProvider.Start(internalConfigChan); err != nil {
		p.logger.Error("Failed to start internal provider",
			logging.GetCodeField(logging.CodeInternalProviderError),
			logging.Error(err),
		)
		return fmt.Errorf("failed to start internal provider: %w", err)
	}
	p.logger.Info("Internal provider started, waiting for configuration...",
		logging.GetCodeField(logging.CodeInternalProviderStarted),
	)

	// Wait for configuration
	select {
	case internalConfig := <-internalConfigChan:
		p.logger.Info("Configuration received from internal provider",
			logging.GetCodeField(logging.CodeConfigGenerationSuccess),
		)

		// Convert to Traefik dynamic configuration
		p.logger.Debug("Converting configuration to Traefik format...")
		traefikConfig := p.convertToTraefikConfig(internalConfig)

		duration := time.Since(startTime)
		// Log stats from internal config since we can't access traefikConfig fields directly
		p.logger.Info("Configuration generation complete",
			logging.GetCodeField(logging.CodeConfigGenerationSuccess),
			logging.Int("routers", len(internalConfig.HTTP.Routers)),
			logging.Int("services", len(internalConfig.HTTP.Services)),
			logging.Int("middlewares", len(internalConfig.HTTP.Middlewares)),
			logging.Duration("duration", duration),
		)

		// Send configuration to Traefik
		p.logger.Info("Sending configuration to Traefik...")
		cfgChan <- traefikConfig
		p.logger.Info("Configuration sent to Traefik successfully",
			logging.GetCodeField(logging.CodeConfigSentSuccess),
		)

		// Stop internal provider
		_ = internalProvider.Stop()
		p.logger.Debug("Internal provider stopped")

	case <-time.After(60 * time.Second):
		p.logger.Error("Timeout waiting for configuration from internal provider (60s)",
			logging.GetCodeField(logging.CodeConfigGenerationError),
		)
		_ = internalProvider.Stop()
		return fmt.Errorf("timeout waiting for configuration")
	}

	p.logger.Info("updateConfig() completed successfully",
		logging.GetCodeField(logging.CodeConfigGenerationSuccess),
	)
	return nil
}

// configWrapper wraps dynamic.Configuration to implement json.Marshaler
type configWrapper struct {
	*dynamic.Configuration
}

// MarshalJSON implements json.Marshaler
func (c *configWrapper) MarshalJSON() ([]byte, error) {
	return json.Marshal(c.Configuration)
}

// convertToTraefikConfig converts our DynamicConfig to Traefik's dynamic.Configuration
func (p *PluginProvider) convertToTraefikConfig(src *provider.DynamicConfig) json.Marshaler {
	cfg := &dynamic.Configuration{
		HTTP: &dynamic.HTTPConfiguration{
			Routers:     make(map[string]*dynamic.Router),
			Services:    make(map[string]*dynamic.Service),
			Middlewares: make(map[string]*dynamic.Middleware),
		},
	}

	// Convert routers
	for name, router := range src.HTTP.Routers {
		cfg.HTTP.Routers[name] = &dynamic.Router{
			Rule:        router.Rule,
			Service:     router.Service,
			Priority:    router.Priority,
			EntryPoints: router.EntryPoints,
			Middlewares: router.Middlewares,
		}
	}

	// Convert services
	for name, service := range src.HTTP.Services {
		servers := make([]dynamic.Server, len(service.LoadBalancer.Servers))
		for i, server := range service.LoadBalancer.Servers {
			servers[i] = dynamic.Server{
				URL: server.URL,
			}
		}

		cfg.HTTP.Services[name] = &dynamic.Service{
			LoadBalancer: &dynamic.ServersLoadBalancer{
				Servers:        servers,
				PassHostHeader: &service.LoadBalancer.PassHostHeader,
			},
		}
	}

	// Convert middlewares
	p.logger.Debug("Converting middlewares to Traefik format",
		logging.Int("count", len(src.HTTP.Middlewares)),
	)
	for name, middleware := range src.HTTP.Middlewares {
		traefikMw := &dynamic.Middleware{}

		// Convert headers middleware (custom request headers)
		// Note: Forwarded headers are configured at entrypoint level in Traefik, not as middleware
		// The forwarded-headers middleware in routes.yml is for the file provider
		if middleware.Headers != nil {
			traefikMw.Headers = &dynamic.Headers{
				CustomRequestHeaders: middleware.Headers.CustomRequestHeaders,
			}
			// Note: ForwardedHeaders in our config is for YAML serialization only
			// Traefik's dynamic.Headers doesn't have a ForwardedHeaders field
			// Forwarded headers should be configured at entrypoint level or via file provider
		}

		cfg.HTTP.Middlewares[name] = traefikMw

		// Log auth middlewares specifically to help debug
		if middleware.Headers != nil && len(middleware.Headers.CustomRequestHeaders) > 0 {
			hasAuth := false
			for headerName := range middleware.Headers.CustomRequestHeaders {
				if headerName == "X-Serverless-Authorization" || headerName == "Authorization" {
					hasAuth = true
					break
				}
			}
			if hasAuth {
				p.logger.Info("✅ Auth middleware converted",
					logging.String("name", name),
					logging.Int("headerCount", len(middleware.Headers.CustomRequestHeaders)),
				)
			}
		}

		// Log forwarded headers middleware (if configured)
		if middleware.Headers != nil && middleware.Headers.ForwardedHeaders != nil {
			p.logger.Debug("✅ Forwarded headers middleware converted",
				logging.String("name", name),
				logging.String("insecure", fmt.Sprintf("%v", middleware.Headers.ForwardedHeaders.Insecure)),
				logging.Int("trustedIPsCount", len(middleware.Headers.ForwardedHeaders.TrustedIPs)),
			)
		}
	}

	return &configWrapper{Configuration: cfg}
}
