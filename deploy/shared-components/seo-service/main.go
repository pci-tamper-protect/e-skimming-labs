package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
)

type SEOService struct {
	projectID   string
	environment string
	mainDomain  string
	labsDomain  string
}

type LabMetadata struct {
	LabID       string    `json:"lab_id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Difficulty  string    `json:"difficulty"`
	Duration    string    `json:"duration"`
	Topics      []string  `json:"topics"`
	Variants    []string  `json:"variants"`
	URL         string    `json:"url"`
	LastUpdated time.Time `json:"last_updated"`
}

type StructuredData struct {
	Context           string                 `json:"@context"`
	Type              string                 `json:"@type"`
	Name              string                 `json:"name"`
	Description       string                 `json:"description"`
	Provider          map[string]interface{} `json:"provider"`
	CourseMode        string                 `json:"courseMode"`
	EducationalLevel  string                 `json:"educationalLevel"`
	Teaches           []string               `json:"teaches"`
}

type SitemapURL struct {
	Loc        string `xml:"loc"`
	Lastmod    string `xml:"lastmod"`
	Changefreq string `xml:"changefreq"`
	Priority   string `xml:"priority"`
}

func main() {
	projectID := os.Getenv("PROJECT_ID")
	environment := os.Getenv("ENVIRONMENT")
	mainDomain := os.Getenv("MAIN_DOMAIN")
	labsDomain := os.Getenv("LABS_DOMAIN")

	if projectID == "" {
		log.Fatal("PROJECT_ID environment variable is required")
	}

	service := &SEOService{
		projectID:   projectID,
		environment: environment,
		mainDomain:  mainDomain,
		labsDomain:  labsDomain,
	}

	// Setup routes
	r := mux.NewRouter()
	
	// Sitemap endpoints
	r.HandleFunc("/api/sitemap.xml", service.handleSitemap).Methods("GET")
	r.HandleFunc("/api/sitemap/labs.xml", service.handleLabsSitemap).Methods("GET")
	r.HandleFunc("/api/sitemap/variants.xml", service.handleVariantsSitemap).Methods("GET")
	
	// Structured data endpoints
	r.HandleFunc("/api/structured-data/lab/{lab_id}", service.handleLabStructuredData).Methods("GET")
	r.HandleFunc("/api/structured-data/collection", service.handleCollectionStructuredData).Methods("GET")
	r.HandleFunc("/api/structured-data/organization", service.handleOrganizationStructuredData).Methods("GET")
	
	// Meta tags endpoints
	r.HandleFunc("/api/meta/lab/{lab_id}", service.handleLabMeta).Methods("GET")
	r.HandleFunc("/api/meta/variant/{lab_id}/{variant}", service.handleVariantMeta).Methods("GET")
	
	// Integration endpoints
	r.HandleFunc("/api/integration/pcioasis", service.handlePcioasisIntegration).Methods("GET")
	r.HandleFunc("/api/integration/sync", service.handleSync).Methods("POST")
	r.HandleFunc("/api/integration/status", service.handleStatus).Methods("GET")
	
	// Health check
	r.HandleFunc("/health", service.handleHealth).Methods("GET")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("SEO service starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func (s *SEOService) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"service": "seo",
		"environment": s.environment,
	})
}

func (s *SEOService) handleSitemap(w http.ResponseWriter, r *http.Request) {
	sitemap := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://%s/</loc>
    <lastmod>%s</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://%s/lab1-basic-magecart</loc>
    <lastmod>%s</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>https://%s/lab2-dom-skimming</loc>
    <lastmod>%s</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>https://%s/lab3-extension-hijacking</loc>
    <lastmod>%s</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
</urlset>`, 
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"),
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"),
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"),
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"))

	w.Header().Set("Content-Type", "application/xml")
	w.Write([]byte(sitemap))
}

func (s *SEOService) handleLabsSitemap(w http.ResponseWriter, r *http.Request) {
	// Generate labs-specific sitemap
	sitemap := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://%s/lab1-basic-magecart</loc>
    <lastmod>%s</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.9</priority>
  </url>
  <url>
    <loc>https://%s/lab2-dom-skimming</loc>
    <lastmod>%s</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.9</priority>
  </url>
  <url>
    <loc>https://%s/lab3-extension-hijacking</loc>
    <lastmod>%s</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.9</priority>
  </url>
</urlset>`,
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"),
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"),
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"))

	w.Header().Set("Content-Type", "application/xml")
	w.Write([]byte(sitemap))
}

func (s *SEOService) handleVariantsSitemap(w http.ResponseWriter, r *http.Request) {
	// Generate variants-specific sitemap
	sitemap := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://%s/lab1-basic-magecart/variant/base</loc>
    <lastmod>%s</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
  <url>
    <loc>https://%s/lab1-basic-magecart/variant/obfuscated-base64</loc>
    <lastmod>%s</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
  <url>
    <loc>https://%s/lab1-basic-magecart/variant/event-listener</loc>
    <lastmod>%s</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
  <url>
    <loc>https://%s/lab1-basic-magecart/variant/websocket</loc>
    <lastmod>%s</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
</urlset>`,
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"),
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"),
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"),
		s.labsDomain, time.Now().Format("2006-01-02T15:04:05Z"))

	w.Header().Set("Content-Type", "application/xml")
	w.Write([]byte(sitemap))
}

func (s *SEOService) handleLabStructuredData(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	labID := vars["lab_id"]

	structuredData := StructuredData{
		Context:          "https://schema.org",
		Type:             "EducationalOccupationalProgram",
		Name:             fmt.Sprintf("E-Skimming Lab: %s", labID),
		Description:      "Interactive cybersecurity lab for learning e-skimming attacks",
		Provider: map[string]interface{}{
			"@type": "Organization",
			"name":  "PCI Oasis",
			"url":   fmt.Sprintf("https://%s", s.mainDomain),
		},
		CourseMode:       "online",
		EducationalLevel: "intermediate",
		Teaches:          []string{"Cybersecurity", "Web Security", "E-commerce Security"},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(structuredData)
}

func (s *SEOService) handleCollectionStructuredData(w http.ResponseWriter, r *http.Request) {
	structuredData := StructuredData{
		Context:          "https://schema.org",
		Type:             "EducationalOccupationalProgram",
		Name:             "E-Skimming Security Labs",
		Description:      "Interactive cybersecurity labs for learning e-skimming attacks and defense techniques",
		Provider: map[string]interface{}{
			"@type": "Organization",
			"name":  "PCI Oasis",
			"url":   fmt.Sprintf("https://%s", s.mainDomain),
		},
		CourseMode:       "online",
		EducationalLevel: "intermediate",
		Teaches:          []string{"Cybersecurity", "Web Security", "E-commerce Security", "Payment Security"},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(structuredData)
}

func (s *SEOService) handleOrganizationStructuredData(w http.ResponseWriter, r *http.Request) {
	structuredData := map[string]interface{}{
		"@context": "https://schema.org",
		"@type":    "Organization",
		"name":     "PCI Oasis",
		"url":      fmt.Sprintf("https://%s", s.mainDomain),
		"description": "Cybersecurity education and training platform",
		"sameAs": []string{
			fmt.Sprintf("https://%s", s.mainDomain),
			fmt.Sprintf("https://%s", s.labsDomain),
		},
		"offers": map[string]interface{}{
			"@type": "EducationalOccupationalProgram",
			"name":  "E-Skimming Security Labs",
			"url":   fmt.Sprintf("https://%s", s.labsDomain),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(structuredData)
}

func (s *SEOService) handleLabMeta(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	labID := vars["lab_id"]

	meta := map[string]string{
		"title":       fmt.Sprintf("E-Skimming Lab: %s - PCI Oasis", labID),
		"description": "Interactive cybersecurity lab for learning e-skimming attacks and defense techniques",
		"keywords":    "cybersecurity, e-skimming, web security, payment security, lab, training",
		"og:title":    fmt.Sprintf("E-Skimming Lab: %s", labID),
		"og:description": "Interactive cybersecurity lab for learning e-skimming attacks",
		"og:url":      fmt.Sprintf("https://%s/%s", s.labsDomain, labID),
		"og:type":     "website",
		"og:site_name": "PCI Oasis Labs",
		"twitter:card": "summary_large_image",
		"twitter:title": fmt.Sprintf("E-Skimming Lab: %s", labID),
		"twitter:description": "Interactive cybersecurity lab for learning e-skimming attacks",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(meta)
}

func (s *SEOService) handleVariantMeta(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	labID := vars["lab_id"]
	variant := vars["variant"]

	meta := map[string]string{
		"title":       fmt.Sprintf("E-Skimming Lab: %s - %s Variant - PCI Oasis", labID, variant),
		"description": fmt.Sprintf("Interactive cybersecurity lab for learning e-skimming attacks using the %s technique", variant),
		"keywords":    fmt.Sprintf("cybersecurity, e-skimming, %s, web security, payment security, lab, training", variant),
		"og:title":    fmt.Sprintf("E-Skimming Lab: %s - %s Variant", labID, variant),
		"og:description": fmt.Sprintf("Interactive cybersecurity lab for learning e-skimming attacks using the %s technique", variant),
		"og:url":      fmt.Sprintf("https://%s/%s/variant/%s", s.labsDomain, labID, variant),
		"og:type":     "website",
		"og:site_name": "PCI Oasis Labs",
		"twitter:card": "summary_large_image",
		"twitter:title": fmt.Sprintf("E-Skimming Lab: %s - %s Variant", labID, variant),
		"twitter:description": fmt.Sprintf("Interactive cybersecurity lab for learning e-skimming attacks using the %s technique", variant),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(meta)
}

func (s *SEOService) handlePcioasisIntegration(w http.ResponseWriter, r *http.Request) {
	integration := map[string]interface{}{
		"labs_domain": s.labsDomain,
		"main_domain": s.mainDomain,
		"labs": []map[string]interface{}{
			{
				"id": "lab1-basic-magecart",
				"title": "Basic Magecart Attack Lab",
				"description": "Learn the fundamentals of Magecart attacks",
				"difficulty": "beginner",
				"duration": "30 minutes",
				"url": fmt.Sprintf("https://%s/lab1-basic-magecart", s.labsDomain),
			},
			{
				"id": "lab2-dom-skimming",
				"title": "DOM Skimming Lab",
				"description": "Advanced DOM manipulation techniques",
				"difficulty": "intermediate",
				"duration": "45 minutes",
				"url": fmt.Sprintf("https://%s/lab2-dom-skimming", s.labsDomain),
			},
			{
				"id": "lab3-extension-hijacking",
				"title": "Browser Extension Hijacking Lab",
				"description": "Browser extension security vulnerabilities",
				"difficulty": "advanced",
				"duration": "60 minutes",
				"url": fmt.Sprintf("https://%s/lab3-extension-hijacking", s.labsDomain),
			},
		},
		"seo_data": map[string]interface{}{
			"sitemap_url": fmt.Sprintf("https://%s/api/sitemap.xml", s.labsDomain),
			"structured_data_url": fmt.Sprintf("https://%s/api/structured-data/collection", s.labsDomain),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(integration)
}

func (s *SEOService) handleSync(w http.ResponseWriter, r *http.Request) {
	// Handle sync with main pcioasis.com site
	response := map[string]string{
		"status": "success",
		"message": "Sync completed",
		"timestamp": time.Now().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (s *SEOService) handleStatus(w http.ResponseWriter, r *http.Request) {
	status := map[string]interface{}{
		"status": "healthy",
		"service": "seo",
		"environment": s.environment,
		"main_domain": s.mainDomain,
		"labs_domain": s.labsDomain,
		"last_sync": time.Now().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}

