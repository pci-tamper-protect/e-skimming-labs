package provider

import (
	"testing"
	"time"
)

func TestNew_ValidConfig(t *testing.T) {
	config := &Config{
		ProjectIDs:   []string{"test-project"},
		Region:       "us-central1",
		PollInterval: 30 * time.Second,
	}

	provider, err := New(config)
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	if provider == nil {
		t.Fatal("Expected provider to be non-nil")
	}

	if provider.config != config {
		t.Error("Provider config doesn't match input config")
	}

	if provider.logger == nil {
		t.Error("Logger should be initialized")
	}

	if provider.tokenManager == nil {
		t.Error("Token manager should be initialized")
	}

	if provider.runService == nil {
		t.Error("Run service should be initialized")
	}
}

func TestNew_NilConfig(t *testing.T) {
	provider, err := New(nil)

	if err == nil {
		t.Fatal("Expected error for nil config")
	}

	if provider != nil {
		t.Error("Expected nil provider for invalid config")
	}

	if err.Error() != "config cannot be nil" {
		t.Errorf("Expected specific error message, got: %v", err)
	}
}

func TestNew_EmptyProjectIDs(t *testing.T) {
	config := &Config{
		ProjectIDs: []string{},
		Region:     "us-central1",
	}

	provider, err := New(config)

	if err == nil {
		t.Fatal("Expected error for empty project IDs")
	}

	if provider != nil {
		t.Error("Expected nil provider for invalid config")
	}

	if err.Error() != "at least one project ID must be specified" {
		t.Errorf("Expected specific error message, got: %v", err)
	}
}

func TestNew_EmptyRegion(t *testing.T) {
	config := &Config{
		ProjectIDs: []string{"test-project"},
		Region:     "",
	}

	provider, err := New(config)

	if err == nil {
		t.Fatal("Expected error for empty region")
	}

	if provider != nil {
		t.Error("Expected nil provider for invalid config")
	}

	if err.Error() != "region must be specified" {
		t.Errorf("Expected specific error message, got: %v", err)
	}
}

func TestNew_DefaultPollInterval(t *testing.T) {
	config := &Config{
		ProjectIDs:   []string{"test-project"},
		Region:       "us-central1",
		PollInterval: 0, // Not set
	}

	_, err := New(config)
	if err != nil {
		t.Fatalf("Expected no error, got: %v", err)
	}

	if config.PollInterval != 30*time.Second {
		t.Errorf("Expected default poll interval of 30s, got: %v", config.PollInterval)
	}
}

func TestProcessService_NoRouterLabels(t *testing.T) {
	config := &Config{
		ProjectIDs: []string{"test-project"},
		Region:     "us-central1",
	}

	provider, err := New(config)
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}

	service := CloudRunService{
		Name:      "test-service",
		ProjectID: "test-project",
		URL:       "https://test-service.run.app",
		Labels:    map[string]string{}, // No traefik labels
	}

	dynamicConfig := NewDynamicConfig()
	err = provider.processService(service, dynamicConfig)

	if err == nil {
		t.Fatal("Expected error for service with no router labels")
	}

	if err.Error() != "no router labels found" {
		t.Errorf("Expected specific error message, got: %v", err)
	}
}

func TestProcessService_WithValidLabels(t *testing.T) {
	config := &Config{
		ProjectIDs: []string{"test-project"},
		Region:     "us-central1",
	}

	provider, err := New(config)
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}

	service := CloudRunService{
		Name:      "test-service",
		ProjectID: "test-project",
		URL:       "https://test-service.run.app",
		Labels: map[string]string{
			"traefik_enable":           "true",
			"traefik_http_routers_test_rule": "Host(`example.com`)",
		},
	}

	dynamicConfig := NewDynamicConfig()
	err = provider.processService(service, dynamicConfig)

	// Error is expected because token fetch will fail in test environment
	// But we should still get the router configured
	if len(dynamicConfig.HTTP.Routers) == 0 {
		t.Error("Expected at least one router to be configured")
	}

	if len(dynamicConfig.HTTP.Services) == 0 {
		t.Error("Expected at least one service to be configured")
	}

	if len(dynamicConfig.HTTP.Middlewares) == 0 {
		t.Error("Expected at least one middleware to be configured")
	}
}

func TestDynamicConfig_AddRouter(t *testing.T) {
	config := NewDynamicConfig()

	routerConfig := RouterConfig{
		Rule:        "Host(`example.com`)",
		Service:     "test-service",
		Middlewares: []string{"auth"},
		Priority:    100,
	}

	config.AddRouter("test-router", routerConfig)

	if len(config.HTTP.Routers) != 1 {
		t.Fatalf("Expected 1 router, got %d", len(config.HTTP.Routers))
	}

	router, ok := config.HTTP.Routers["test-router"]
	if !ok {
		t.Fatal("Router not found in config")
	}

	if router.Rule != "Host(`example.com`)" {
		t.Errorf("Expected rule Host(`example.com`), got: %s", router.Rule)
	}

	if router.Service != "test-service" {
		t.Errorf("Expected service test-service, got: %s", router.Service)
	}

	if router.Priority != 100 {
		t.Errorf("Expected priority 100, got: %d", router.Priority)
	}
}

func TestDynamicConfig_AddService(t *testing.T) {
	config := NewDynamicConfig()

	serviceConfig := ServiceConfig{
		LoadBalancer: LoadBalancerConfig{
			Servers: []ServerConfig{
				{URL: "https://service1.run.app"},
				{URL: "https://service2.run.app"},
			},
			PassHostHeader: false,
		},
	}

	config.AddService("test-service", serviceConfig)

	if len(config.HTTP.Services) != 1 {
		t.Fatalf("Expected 1 service, got %d", len(config.HTTP.Services))
	}

	service, ok := config.HTTP.Services["test-service"]
	if !ok {
		t.Fatal("Service not found in config")
	}

	if len(service.LoadBalancer.Servers) != 2 {
		t.Errorf("Expected 2 servers, got %d", len(service.LoadBalancer.Servers))
	}

	if service.LoadBalancer.PassHostHeader != false {
		t.Error("Expected PassHostHeader to be false")
	}
}

func TestDynamicConfig_AddAuthMiddleware(t *testing.T) {
	config := NewDynamicConfig()

	config.AddAuthMiddleware("test-auth", "test-token-123")

	if len(config.HTTP.Middlewares) != 1 {
		t.Fatalf("Expected 1 middleware, got %d", len(config.HTTP.Middlewares))
	}

	middleware, ok := config.HTTP.Middlewares["test-auth"]
	if !ok {
		t.Fatal("Middleware not found in config")
	}

	if len(middleware.Headers.CustomRequestHeaders) != 1 {
		t.Fatalf("Expected 1 custom header, got %d", len(middleware.Headers.CustomRequestHeaders))
	}

	authHeader, ok := middleware.Headers.CustomRequestHeaders["Authorization"]
	if !ok {
		t.Fatal("Authorization header not found")
	}

	if authHeader != "Bearer test-token-123" {
		t.Errorf("Expected 'Bearer test-token-123', got: %s", authHeader)
	}
}

func TestDynamicConfig_AddAuthMiddleware_EmptyToken(t *testing.T) {
	config := NewDynamicConfig()

	config.AddAuthMiddleware("test-auth", "")

	middleware, ok := config.HTTP.Middlewares["test-auth"]
	if !ok {
		t.Fatal("Middleware not found in config")
	}

	authHeader, ok := middleware.Headers.CustomRequestHeaders["Authorization"]
	if !ok {
		t.Fatal("Authorization header not found")
	}

	if authHeader != "Bearer TOKEN_FETCH_FAILED" {
		t.Errorf("Expected error marker for empty token, got: %s", authHeader)
	}
}

func TestDynamicConfig_AddTraefikInternalRouters(t *testing.T) {
	config := NewDynamicConfig()

	config.AddTraefikInternalRouters()

	// Should add API and dashboard routers
	if len(config.HTTP.Routers) < 2 {
		t.Errorf("Expected at least 2 routers (api and dashboard), got %d", len(config.HTTP.Routers))
	}

	if _, ok := config.HTTP.Routers["traefik-api"]; !ok {
		t.Error("Expected traefik-api router")
	}

	if _, ok := config.HTTP.Routers["traefik-dashboard"]; !ok {
		t.Error("Expected traefik-dashboard router")
	}
}
