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
