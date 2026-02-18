package provider

import (
	"fmt"
	"os"
	"strings"
)

// RouterConfig represents a Traefik router configuration
type RouterConfig struct {
	Rule        string
	Service     string
	Priority    int
	EntryPoints []string
	Middlewares []string
}

// ServiceConfig represents a Traefik service configuration
type ServiceConfig struct {
	LoadBalancer LoadBalancerConfig
}

// LoadBalancerConfig represents load balancer configuration
type LoadBalancerConfig struct {
	Servers        []ServerConfig
	PassHostHeader bool
}

// ServerConfig represents a backend server configuration
type ServerConfig struct {
	URL string
}

// ruleMap maps rule IDs to Traefik rule expressions.
// It starts empty and is populated from config via SetRuleMap.
var ruleMap = map[string]string{}

// SetRuleMap replaces the package-level ruleMap with the provided mappings.
// This is called during provider initialization to inject rule mappings from config.
// The provided map is copied so callers cannot mutate provider state after initialization.
func SetRuleMap(m map[string]string) {
	if m == nil {
		return
	}
	copied := make(map[string]string, len(m))
	for k, v := range m {
		copied[k] = v
	}
	ruleMap = copied
}

// defaultPriorityMap maps router names to default priorities
// Higher priority = matched first. home-index has lowest priority (catch-all)
// Priority guide:
//   - 1: catch-all routes (home-index root "/")
//   - 100: sign-in/sign-up routes
//   - 200: main lab routes (/lab1, /lab2, /lab3)
//   - 250: static asset routes (/lab1/css/, etc.)
//   - 300: sub-routes (/lab1/c2, /lab3/extension)
//   - 500: API routes (/api/seo, /api/analytics)
//   - 1000: internal routes (dashboard, api)
var defaultPriorityMap = map[string]int{
	"home-index":        1,   // Lowest priority - catch-all for "/"
	"home-index-root":   1,   // Lowest priority - catch-all for "/"
	"home-index-signin": 100, // Sign-in pages
	"home-seo":          500, // API routes
	"labs-analytics":    500, // API routes
	"lab1":              200, // Main lab routes (legacy)
	"lab1-main":         200, // Main lab routes (aligned with lab2-main, lab3-main)
	"lab1-static":       250, // Static assets (more specific)
	"lab1-c2":           300, // Sub-routes (most specific)
	"lab2":              200,
	"lab2-main":         200,
	"lab2-static":       250,
	"lab2-c2":           300,
	"lab3":              200,
	"lab3-main":         200,
	"lab3-static":       250,
	"lab3-extension":    300,
}

// getDefaultPriority returns the default priority for a router name
// Falls back to 200 for unknown routers (reasonable default for app routes)
func getDefaultPriority(routerName string) int {
	if priority, ok := defaultPriorityMap[routerName]; ok {
		return priority
	}
	// Default to 200 for unknown routes (higher than home-index catch-all)
	return 200
}

// extractRouterConfigs extracts router configurations from Cloud Run service labels
// Extracted from cmd/generate-routes/main.go:410-507
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
				Priority:    getDefaultPriority(routerName), // Use smart default based on router name
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
			} else {
				fmt.Fprintf(os.Stderr, "   WARNING: rule_id '%s' for router '%s' (service '%s') not found in ruleMap — router will have empty rule\n", value, routerName, serviceName)
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

// extractServicePort extracts the port from service labels
func extractServicePort(labels map[string]string, serviceName string) int {
	port := 8080 // Default port

	if portStr, ok := labels[fmt.Sprintf("traefik_http_services_%s_lb_port", serviceName)]; ok {
		fmt.Sscanf(portStr, "%d", &port)
	} else if portStr, ok := labels[fmt.Sprintf("traefik_http_services_%s_loadbalancer_server_port", serviceName)]; ok {
		fmt.Sscanf(portStr, "%d", &port)
	}

	return port
}
