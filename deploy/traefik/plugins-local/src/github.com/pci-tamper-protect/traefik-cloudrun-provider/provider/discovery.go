package provider

import (
	"encoding/json"
	"fmt"
	"strings"

	run "google.golang.org/api/run/v1"
)

// preferredServiceURL returns the best URL for a Cloud Run service.
// Cloud Run services have two URL formats:
//   - New format: https://SERVICE-PROJECT_NUMBER.REGION.run.app (preferred)
//   - Old format: https://SERVICE-HASH-REGION.a.run.app (may have GFE routing issues for GET /)
//
// We prefer the new format URL (project-number based) because the old hash-based URL
// can return 404 for GET / in some cases (IAM policy + GFE routing edge case).
func preferredServiceURL(svc *run.Service) string {
	if svc.Metadata == nil || svc.Metadata.Annotations == nil {
		return svc.Status.Url
	}

	urlsJSON, ok := svc.Metadata.Annotations["run.googleapis.com/urls"]
	if !ok || urlsJSON == "" {
		return svc.Status.Url
	}

	var urls []string
	if err := json.Unmarshal([]byte(urlsJSON), &urls); err != nil || len(urls) == 0 {
		return svc.Status.Url
	}

	// New format: PROJECT_NUMBER.REGION.run.app (not *.a.run.app)
	for _, u := range urls {
		if !strings.HasSuffix(u, ".a.run.app") {
			return u
		}
	}

	return svc.Status.Url
}

// CloudRunService represents a discovered Cloud Run service with Traefik labels
type CloudRunService struct {
	Name      string
	URL       string
	ProjectID string
	Region    string
	Labels    map[string]string
}

// listServices lists Cloud Run services with traefik_enable=true label
// Extracted from cmd/generate-routes/main.go:237-275
func (p *Provider) listServices(runService *run.APIService, projectID, region string) ([]CloudRunService, error) {
	parent := fmt.Sprintf("projects/%s/locations/%s", projectID, region)

	var services []CloudRunService
	pageToken := ""

	for {
		call := runService.Projects.Locations.Services.List(parent)
		if pageToken != "" {
			call = call.Continue(pageToken)
		}

		resp, err := call.Do()
		if err != nil {
			return nil, fmt.Errorf("failed to list services in %s/%s: %w", projectID, region, err)
		}

		if resp.Items != nil {
			for _, svc := range resp.Items {
				// Check if service has traefik_enable=true label
				// Check both service-level labels (set by --labels) and template metadata labels
				var labels map[string]string
				var hasTraefikEnable bool
				
				// First check service-level labels (metadata.labels) - set by gcloud run deploy --labels
				if svc.Metadata != nil && svc.Metadata.Labels != nil {
					if enabled, ok := svc.Metadata.Labels["traefik_enable"]; ok && enabled == "true" {
						hasTraefikEnable = true
						labels = svc.Metadata.Labels
					}
				}
				
				// Fall back to template metadata labels if not found in service-level labels
				if !hasTraefikEnable && svc.Spec != nil && svc.Spec.Template != nil && svc.Spec.Template.Metadata != nil {
					if svc.Spec.Template.Metadata.Labels != nil {
						if enabled, ok := svc.Spec.Template.Metadata.Labels["traefik_enable"]; ok && enabled == "true" {
							hasTraefikEnable = true
							labels = svc.Spec.Template.Metadata.Labels
						}
					}
				}
				
				if hasTraefikEnable && labels != nil {
					services = append(services, CloudRunService{
						Name:      svc.Metadata.Name,
						URL:       preferredServiceURL(svc),
						ProjectID: projectID,
						Region:    region,
						Labels:    labels,
					})
				}
			}
		}

		// Check for next page token in metadata
		if resp.Metadata == nil || resp.Metadata.Continue == "" {
			break
		}
		pageToken = resp.Metadata.Continue
	}

	return services, nil
}

// getServiceDetails gets detailed information about a single Cloud Run service
func (p *Provider) getServiceDetails(runService *run.APIService, projectID, region, serviceName string) (*run.Service, error) {
	parent := fmt.Sprintf("projects/%s/locations/%s/services/%s", projectID, region, serviceName)
	service, err := runService.Projects.Locations.Services.Get(parent).Do()
	if err != nil {
		return nil, fmt.Errorf("failed to get service %s: %w", serviceName, err)
	}
	return service, nil
}
