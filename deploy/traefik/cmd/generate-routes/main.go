package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	run "google.golang.org/api/run/v1"
	"gopkg.in/yaml.v3"
)

const (
	defaultEnvironment = "stg"
	defaultRegion      = "us-central1"
	defaultOutputFile  = "/etc/traefik/dynamic/routes.yml"
)

var ruleMap = map[string]string{
	"home-index-root":    "PathPrefix(`/`)",
	"home-index-signin":  "Path(`/sign-in`) || Path(`/sign-up`)",
	"home-seo":           "PathPrefix(`/api/seo`)",
	"labs-analytics":     "PathPrefix(`/api/analytics`)",
	"lab1":               "PathPrefix(`/lab1`)",
	"lab1-static":        "PathPrefix(`/lab1/css/`) || PathPrefix(`/lab1/js/`) || PathPrefix(`/lab1/images/`) || PathPrefix(`/lab1/img/`) || PathPrefix(`/lab1/static/`) || PathPrefix(`/lab1/assets/`)",
	"lab1-c2":            "PathPrefix(`/lab1/c2`)",
	"lab2":               "PathPrefix(`/lab2`)",
	"lab2-static":        "PathPrefix(`/lab2/css/`) || PathPrefix(`/lab2/js/`) || PathPrefix(`/lab2/images/`) || PathPrefix(`/lab2/img/`) || PathPrefix(`/lab2/static/`) || PathPrefix(`/lab2/assets/`)",
	"lab2-c2":            "PathPrefix(`/lab2/c2`)",
	"lab3":               "PathPrefix(`/lab3`)",
	"lab3-static":        "PathPrefix(`/lab3/css/`) || PathPrefix(`/lab3/js/`) || PathPrefix(`/lab3/images/`) || PathPrefix(`/lab3/img/`) || PathPrefix(`/lab3/static/`) || PathPrefix(`/lab3/assets/`)",
	"lab3-extension":     "PathPrefix(`/lab3/extension`)",
}

type Config struct {
	Environment   string
	LabsProjectID string
	HomeProjectID string
	Region        string
	OutputFile    string
}

type RouterConfig struct {
	Rule         string   `yaml:"rule"`
	Service      string   `yaml:"service"`
	Priority     int      `yaml:"priority"`
	EntryPoints  []string `yaml:"entryPoints"`  // Must be plural (entryPoints), not singular (entryPoint)
	Middlewares  []string `yaml:"middlewares,omitempty"`
}

type ServiceConfig struct {
	LoadBalancer struct {
		Servers        []ServerConfig `yaml:"servers"`
		PassHostHeader bool           `yaml:"passHostHeader"`
	} `yaml:"loadBalancer"`
}

type ServerConfig struct {
	URL string `yaml:"url"`
}

type AuthMiddleware struct {
	Headers struct {
		CustomRequestHeaders map[string]string `yaml:"customRequestHeaders"`
	} `yaml:"headers"`
}

type RoutesConfig struct {
	HTTP struct {
		Routers     map[string]RouterConfig `yaml:"routers"`
		Services    map[string]ServiceConfig `yaml:"services"`
		Middlewares map[string]AuthMiddleware `yaml:"middlewares"`
	} `yaml:"http"`
}

func main() {
	// Log startup - this log is used by debug scripts to verify execution
	fmt.Fprintf(os.Stderr, "🚀 Starting generate-routes-from-labels (Go) at %s\n", time.Now().UTC().Format(time.RFC3339))

	config := loadConfig()

	fmt.Fprintf(os.Stderr, "🔍 Generating Traefik routes from Cloud Run service labels...\n")
	fmt.Fprintf(os.Stderr, "   Environment: %s\n", config.Environment)
	fmt.Fprintf(os.Stderr, "   Labs Project: %s\n", config.LabsProjectID)
	fmt.Fprintf(os.Stderr, "   Home Project: %s\n", config.HomeProjectID)
	fmt.Fprintf(os.Stderr, "   Region: %s\n", config.Region)
	fmt.Fprintf(os.Stderr, "   Output: %s\n", config.OutputFile)
	fmt.Fprintf(os.Stderr, "\n")

	// Create output directory
	if err := os.MkdirAll(getDir(config.OutputFile), 0755); err != nil {
		log.Fatalf("Failed to create output directory: %v", err)
	}

	// Initialize Cloud Run client
	// Uses Application Default Credentials (ADC):
	// 1. GOOGLE_APPLICATION_CREDENTIALS env var (service account key file)
	// 2. ~/.config/gcloud/application_default_credentials.json (user credentials)
	// 3. Metadata server (in Cloud Run/GCE)
	ctx := context.Background()
	runService, err := run.NewService(ctx)
	if err != nil {
		log.Fatalf("Failed to create Cloud Run service: %v", err)
	}
	// runService is *run.APIService

	// Generate routes
	routes := &RoutesConfig{}
	routes.HTTP.Routers = make(map[string]RouterConfig)
	routes.HTTP.Services = make(map[string]ServiceConfig)
	routes.HTTP.Middlewares = make(map[string]AuthMiddleware)

	// Add Traefik API and Dashboard routers
	routes.HTTP.Routers["traefik-api"] = RouterConfig{
		Rule:        "PathPrefix(`/api/http`) || PathPrefix(`/api/rawdata`) || PathPrefix(`/api/overview`) || Path(`/api/version`)",
		Service:     "api@internal",
		Priority:    1000,
		EntryPoints: []string{"web"},
	}
	routes.HTTP.Routers["traefik-dashboard"] = RouterConfig{
		Rule:        "PathPrefix(`/dashboard`)",
		Service:     "api@internal",
		Priority:    1000,
		EntryPoints: []string{"web"},
	}

	// Process services from both projects
	processedServices := make(map[string]bool)
	authMiddlewares := make(map[string]bool)

	projects := []struct {
		ID   string
		Name string
	}{
		{ID: config.LabsProjectID, Name: "labs"},
		{ID: config.HomeProjectID, Name: "home"},
	}

	for _, project := range projects {
		if project.ID == "" {
			continue
		}

		fmt.Fprintf(os.Stderr, "   DEBUG: Querying %s project via Go SDK: %s\n", project.Name, project.ID)
		services, err := listServices(runService, project.ID, config.Region)
		if err != nil {
			fmt.Fprintf(os.Stderr, "   ⚠️  Warning: Failed to query %s project: %v\n", project.Name, err)
			continue
		}

		fmt.Fprintf(os.Stderr, "   DEBUG: Found %d service(s) in %s project\n", len(services), project.Name)

		for _, serviceName := range services {
			if err := processService(runService, project.ID, config.Region, serviceName, routes, processedServices, authMiddlewares); err != nil {
				fmt.Fprintf(os.Stderr, "   ⚠️  Warning: Failed to process service %s: %v\n", serviceName, err)
				continue
			}
		}
	}

	// Write routes.yml
	if err := writeRoutes(config.OutputFile, routes); err != nil {
		log.Fatalf("Failed to write routes file: %v", err)
	}

	fmt.Fprintf(os.Stderr, "\n✅ Routes file generated at %s\n", config.OutputFile)
	fmt.Fprintf(os.Stderr, "\n📊 Summary:\n")
	if len(authMiddlewares) == 0 {
		fmt.Fprintf(os.Stderr, "   ❌ FAILURE: Auth middlewares created: NONE (no services processed)\n")
	} else {
		mwList := make([]string, 0, len(authMiddlewares))
		for mw := range authMiddlewares {
			mwList = append(mwList, mw)
		}
		fmt.Fprintf(os.Stderr, "   ✅ SUCCESS: Auth middlewares created: %s\n", strings.Join(mwList, ", "))
	}
	if len(processedServices) == 0 {
		fmt.Fprintf(os.Stderr, "   ❌ FAILURE: Processed services: NONE (no services found or processing failed)\n")
	} else {
		svcList := make([]string, 0, len(processedServices))
		for svc := range processedServices {
			svcList = append(svcList, svc)
		}
		fmt.Fprintf(os.Stderr, "   ✅ SUCCESS: Processed services: %s\n", strings.Join(svcList, ", "))
	}
	fmt.Fprintf(os.Stderr, "   Routers: %d\n", len(routes.HTTP.Routers))
	fmt.Fprintf(os.Stderr, "   Services: %d\n", len(routes.HTTP.Services))
}

func loadConfig() *Config {
	env := os.Getenv("ENVIRONMENT")
	if env == "" {
		env = defaultEnvironment
	}

	labsProject := os.Getenv("LABS_PROJECT_ID")
	if labsProject == "" {
		labsProject = fmt.Sprintf("labs-%s", env)
	}

	homeProject := os.Getenv("HOME_PROJECT_ID")
	if homeProject == "" {
		homeProject = fmt.Sprintf("labs-home-%s", env)
	}

	region := os.Getenv("REGION")
	if region == "" {
		region = defaultRegion
	}

	outputFile := defaultOutputFile
	if len(os.Args) > 1 {
		outputFile = os.Args[1]
	}

	return &Config{
		Environment:   env,
		LabsProjectID: labsProject,
		HomeProjectID: homeProject,
		Region:        region,
		OutputFile:    outputFile,
	}
}

func getDir(path string) string {
	parts := strings.Split(path, "/")
	if len(parts) > 1 {
		return strings.Join(parts[:len(parts)-1], "/")
	}
	return "."
}

func listServices(runService *run.APIService, projectID, region string) ([]string, error) {
	parent := fmt.Sprintf("projects/%s/locations/%s", projectID, region)

	var serviceNames []string
	pageToken := ""

	for {
		call := runService.Projects.Locations.Services.List(parent)
		if pageToken != "" {
			call = call.Continue(pageToken)
		}

		resp, err := call.Do()
		if err != nil {
			return nil, fmt.Errorf("failed to list services: %w", err)
		}

		if resp.Items != nil {
			for _, svc := range resp.Items {
				// Check if service has traefik_enable=true label
				if svc.Spec != nil && svc.Spec.Template != nil && svc.Spec.Template.Metadata != nil {
					if svc.Spec.Template.Metadata.Labels != nil {
						if enabled, ok := svc.Spec.Template.Metadata.Labels["traefik_enable"]; ok && enabled == "true" {
							serviceNames = append(serviceNames, svc.Metadata.Name)
						}
					}
				}
			}
		}

		// Check for next page token in metadata
		if resp.Metadata == nil || resp.Metadata.Continue == "" {
			break
		}
		pageToken = resp.Metadata.Continue
	}

	return serviceNames, nil
}

func processService(runService *run.APIService, projectID, region, serviceName string, routes *RoutesConfig, processedServices map[string]bool, authMiddlewares map[string]bool) error {
	fmt.Fprintf(os.Stderr, "  📋 Processing: %s (%s)\n", serviceName, projectID)

	// Get service details
	parent := fmt.Sprintf("projects/%s/locations/%s/services/%s", projectID, region, serviceName)
	service, err := runService.Projects.Locations.Services.Get(parent).Do()
	if err != nil {
		return fmt.Errorf("failed to get service: %w", err)
	}

	if service.Spec == nil || service.Spec.Template == nil || service.Spec.Template.Metadata == nil {
		return fmt.Errorf("service has no metadata")
	}

	labels := service.Spec.Template.Metadata.Labels
	if labels == nil {
		return fmt.Errorf("service has no labels")
	}

	// Get service URL
	serviceURL := service.Status.Url
	if serviceURL == "" {
		return fmt.Errorf("service has no URL")
	}

	fmt.Fprintf(os.Stderr, "    ✅ SUCCESS: Service details fetched for %s\n", serviceName)
	fmt.Fprintf(os.Stderr, "    ✅ SUCCESS: Service URL found: %s\n", serviceURL)

	// Get identity token
	serviceToken, err := getIdentityToken(serviceURL)
	if err != nil {
		fmt.Fprintf(os.Stderr, "    ❌ FAILURE: Token fetch failed for %s: %v\n", serviceName, err)
		// Continue anyway - middleware will be created without token
	} else {
		fmt.Fprintf(os.Stderr, "    ✅ SUCCESS: Identity token fetched for %s (%d chars)\n", serviceName, len(serviceToken))
	}

	// Extract router labels
	routerConfigs := extractRouterConfigs(labels, serviceName)
	if len(routerConfigs) == 0 {
		fmt.Fprintf(os.Stderr, "    ❌ FAILURE: No router labels found for %s\n", serviceName)
		return fmt.Errorf("no router labels found")
	}

	fmt.Fprintf(os.Stderr, "    ✅ SUCCESS: Found %d router label(s) for %s\n", len(routerConfigs), serviceName)

	// Determine service name from label (used for service definition and auth middleware)
	serviceNameFromLabel := serviceName
	for _, router := range routerConfigs {
		if router.Service != "" {
			serviceNameFromLabel = router.Service
			break
		}
	}

	// Add auth middleware to all routers
	authMiddlewareName := fmt.Sprintf("%s-auth", serviceNameFromLabel)
	for routerName := range routerConfigs {
		// Get the router config, modify it, then put it back (can't modify map values directly)
		router := routerConfigs[routerName]

		// Add auth middleware if not already present
		found := false
		for _, mw := range router.Middlewares {
			if mw == authMiddlewareName || mw == fmt.Sprintf("%s@file", authMiddlewareName) {
				found = true
				break
			}
		}
		if !found {
			router.Middlewares = append(router.Middlewares, authMiddlewareName)
		}
		// Always add retry-cold-start
		hasRetry := false
		for _, mw := range router.Middlewares {
			if mw == "retry-cold-start@file" {
				hasRetry = true
				break
			}
		}
		if !hasRetry {
			router.Middlewares = append(router.Middlewares, "retry-cold-start@file")
		}

		// Put the modified router back in the map
		routerConfigs[routerName] = router
	}

	// Add routers to routes
	for routerName, router := range routerConfigs {
		routes.HTTP.Routers[routerName] = router
	}

	// Add service definition (only once per service name)
	if !processedServices[serviceNameFromLabel] {
		processedServices[serviceNameFromLabel] = true

		// Get service port from labels (not used in YAML, but kept for reference)
		port := 8080
		if portStr, ok := labels[fmt.Sprintf("traefik_http_services_%s_lb_port", serviceNameFromLabel)]; ok {
			fmt.Sscanf(portStr, "%d", &port)
		} else if portStr, ok := labels[fmt.Sprintf("traefik_http_services_%s_loadbalancer_server_port", serviceNameFromLabel)]; ok {
			fmt.Sscanf(portStr, "%d", &port)
		}

		serviceConfig := ServiceConfig{}
		serviceConfig.LoadBalancer.Servers = []ServerConfig{{URL: serviceURL}}
		serviceConfig.LoadBalancer.PassHostHeader = false
		routes.HTTP.Services[serviceNameFromLabel] = serviceConfig

		fmt.Fprintf(os.Stderr, "    ✅ Service definition uses URL: %s (matches token audience)\n", serviceURL)

		// Create auth middleware
		if !authMiddlewares[authMiddlewareName] {
			authMiddlewares[authMiddlewareName] = true
			fmt.Fprintf(os.Stderr, "    ✅ SUCCESS: Adding auth middleware '%s' to routes.yml\n", authMiddlewareName)

			mw := AuthMiddleware{}
			mw.Headers.CustomRequestHeaders = make(map[string]string)
			if serviceToken != "" {
				mw.Headers.CustomRequestHeaders["Authorization"] = fmt.Sprintf("Bearer %s", serviceToken)
				fmt.Fprintf(os.Stderr, "    ✅ SUCCESS: Auth middleware '%s' created with token (%d chars)\n", authMiddlewareName, len(serviceToken))
			} else {
				mw.Headers.CustomRequestHeaders["Authorization"] = "Bearer TOKEN_FETCH_FAILED"
				fmt.Fprintf(os.Stderr, "    ⚠️  WARNING: Auth middleware '%s' created with error marker - will need token before service is made private\n", authMiddlewareName)
			}
			routes.HTTP.Middlewares[authMiddlewareName] = mw
		}
	}

	return nil
}

func extractRouterConfigs(labels map[string]string, serviceName string) map[string]RouterConfig {
	routers := make(map[string]RouterConfig)

	// Find all router labels
	for key, value := range labels {
		if !strings.HasPrefix(key, "traefik_http_routers_") {
			continue
		}

		// Parse: traefik_http_routers_<router-name>_<property>
		parts := strings.SplitN(key, "_", 5)
		if len(parts) < 5 {
			continue
		}

		routerName := parts[3]
		property := parts[4]

		if routers[routerName].Rule == "" {
			routers[routerName] = RouterConfig{
				Priority:    1,
				EntryPoints: []string{"web"}, // Always set entryPoints (plural) - required by Traefik
				Middlewares: []string{},
			}
		}

		router := routers[routerName]

		// Ensure entryPoints is always set (required by Traefik)
		if len(router.EntryPoints) == 0 {
			router.EntryPoints = []string{"web"}
		}

		switch property {
		case "rule":
			// Check if it's a rule_id that needs mapping
			if mappedRule, ok := ruleMap[value]; ok {
				router.Rule = mappedRule
			} else {
				router.Rule = value
			}
		case "rule_id":
			if mappedRule, ok := ruleMap[value]; ok {
				router.Rule = mappedRule
			}
		case "service":
			router.Service = value
		case "priority":
			fmt.Sscanf(value, "%d", &router.Priority)
		case "entrypoints":
			router.EntryPoints = strings.Split(value, ",")
			for i := range router.EntryPoints {
				router.EntryPoints[i] = strings.TrimSpace(router.EntryPoints[i])
			}
			// Ensure at least one entryPoint
			if len(router.EntryPoints) == 0 {
				router.EntryPoints = []string{"web"}
			}
		case "middlewares":
			// Support multiple separators: __ (preferred), ; (legacy), , (legacy)
			var parts []string
			if strings.Contains(value, "__") {
				parts = strings.Split(value, "__")
			} else if strings.Contains(value, ";") {
				parts = strings.Split(value, ";")
			} else {
				parts = strings.Split(value, ",")
			}
			for _, part := range parts {
				part = strings.TrimSpace(part)
				if part != "" {
					// Convert -file suffix to @file
					if strings.HasSuffix(part, "-file") {
						part = strings.TrimSuffix(part, "-file") + "@file"
					}
					router.Middlewares = append(router.Middlewares, part)
				}
			}
		}

		// Final check: ensure entryPoints is set before adding to map
		if len(router.EntryPoints) == 0 {
			router.EntryPoints = []string{"web"}
		}
		routers[routerName] = router
	}

	// Final validation: ensure all routers have entryPoints (required by Traefik)
	for routerName, router := range routers {
		if len(router.EntryPoints) == 0 {
			fmt.Fprintf(os.Stderr, "   WARNING: Router %s has no entryPoints, defaulting to 'web'\n", routerName)
			router.EntryPoints = []string{"web"}
			routers[routerName] = router
		}
	}

	return routers
}

func getIdentityToken(audience string) (string, error) {
	// Use metadata server to get identity token
	encodedAudience := strings.ReplaceAll(strings.ReplaceAll(audience, ":", "%3A"), "/", "%2F")
	url := fmt.Sprintf("http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=%s", encodedAudience)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Metadata-Flavor", "Google")

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("metadata server returned %d: %s", resp.StatusCode, string(body))
	}

	token, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	tokenStr := strings.TrimSpace(string(token))
	if !strings.HasPrefix(tokenStr, "eyJ") {
		return "", fmt.Errorf("token doesn't look valid (doesn't start with eyJ)")
	}

	return tokenStr, nil
}

func writeRoutes(outputFile string, routes *RoutesConfig) error {
	file, err := os.Create(outputFile)
	if err != nil {
		return err
	}
	defer file.Close()

	// Write header comment
	fmt.Fprintf(file, "# Auto-generated Traefik routes from Cloud Run service labels\n")
	fmt.Fprintf(file, "# Generated at: %s\n", time.Now().UTC().Format(time.RFC3339))
	fmt.Fprintf(file, "# Environment: %s\n", os.Getenv("ENVIRONMENT"))
	fmt.Fprintf(file, "#\n")
	fmt.Fprintf(file, "# This file is generated by reading Traefik labels from Cloud Run services.\n")
	fmt.Fprintf(file, "# Labels follow the same format as docker-compose.yml\n\n")

	// Write YAML
	encoder := yaml.NewEncoder(file)
	encoder.SetIndent(2)
	if err := encoder.Encode(routes); err != nil {
		return err
	}

	return encoder.Close()
}
