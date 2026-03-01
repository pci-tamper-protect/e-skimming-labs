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

// ruleMap maps rule IDs to Traefik rule expressions
// Extracted from cmd/generate-routes/main.go:23-37
var ruleMap = map[string]string{
	"home-index-root":   "PathPrefix(`/`)",
	"home-index-signin": "Path(`/sign-in`) || Path(`/sign-up`)",
	"home-seo":          "PathPrefix(`/api/seo`)",
	"labs-analytics":    "PathPrefix(`/api/analytics`)",
	"lab1-health":        "Path(`/lab1/health`)",
	"lab2-health":        "Path(`/lab2/health`)",
	"lab3-health":        "Path(`/lab3/health`)",
	"lab4-health":        "Path(`/lab4/health`)",
	"lab1":              "PathPrefix(`/lab1`)",
	"lab1-main":         "PathPrefix(`/lab1`)",
	"lab1-static":       "PathPrefix(`/lab1/css/`) || PathPrefix(`/lab1/js/`) || PathPrefix(`/lab1/images/`) || PathPrefix(`/lab1/img/`) || PathPrefix(`/lab1/static/`) || PathPrefix(`/lab1/assets/`)",
	"lab1-c2":           "PathPrefix(`/lab1/c2`)",
	"lab2":              "PathPrefix(`/lab2`)",
	"lab2-main":         "PathPrefix(`/lab2`)",
	"lab2-static":       "PathPrefix(`/lab2/css/`) || PathPrefix(`/lab2/js/`) || PathPrefix(`/lab2/images/`) || PathPrefix(`/lab2/img/`) || PathPrefix(`/lab2/static/`) || PathPrefix(`/lab2/assets/`)",
	"lab2-c2":           "PathPrefix(`/lab2/c2`)",
	"lab3":              "PathPrefix(`/lab3`)",
	"lab3-main":         "PathPrefix(`/lab3`)",
	"lab3-static":       "PathPrefix(`/lab3/css/`) || PathPrefix(`/lab3/js/`) || PathPrefix(`/lab3/images/`) || PathPrefix(`/lab3/img/`) || PathPrefix(`/lab3/static/`) || PathPrefix(`/lab3/assets/`)",
	"lab3-extension":    "PathPrefix(`/lab3/extension`)",
	"lab4":              "PathPrefix(`/lab4`)",
	"lab4-main":         "PathPrefix(`/lab4`)",
	"lab4-static":       "PathPrefix(`/lab4/css/`) || PathPrefix(`/lab4/js/`) || PathPrefix(`/lab4/images/`) || PathPrefix(`/lab4/img/`) || PathPrefix(`/lab4/static/`) || PathPrefix(`/lab4/assets/`)",
	"lab4-c2":           "PathPrefix(`/lab4/c2`)",
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
	"lab1-health":       400, // Health warmup routes (no auth)
	"lab2-health":       400,
	"lab3-health":       400,
	"lab4-health":       400,
	"home-index":        1,   // Lowest priority - catch-all for "/"
	"home-index-root":   1,   // Lowest priority - catch-all for "/"
	"home-index-signin": 100, // Sign-in pages
	"home-seo":          500, // API routes
	"labs-analytics":    500, // API routes
	"lab1":              200, // Main lab routes
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
	"lab4":              200,
	"lab4-main":         200,
	"lab4-static":       250,
	"lab4-c2":           300,
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
//
//nolint:gocyclo
func extractRouterConfigs(labels map[string]string, _ string) map[string]RouterConfig {
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

		if _, exists := routers[routerName]; !exists {
			routers[routerName] = RouterConfig{
				Priority:    getDefaultPriority(routerName), // Use smart default based on router name
				EntryPoints: []string{"web"},                // Always set entryPoints (plural) - required by Traefik
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
			if _, err := fmt.Sscanf(value, "%d", &router.Priority); err != nil {
				router.Priority = 0
			}
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
