package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/gorilla/mux"
	"google.golang.org/api/option"
)

type AnalyticsService struct {
	firestoreClient *firestore.Client
	projectID       string
	environment     string
}

type ProgressData struct {
	SessionID   string                 `json:"session_id"`
	LabID       string                 `json:"lab_id"`
	Variant     string                 `json:"variant"`
	Progress    map[string]interface{} `json:"progress"`
	Completion  map[string]interface{} `json:"completion"`
	LastUpdated time.Time              `json:"last_updated"`
}

type AnalyticsEvent struct {
	EventType string                 `json:"event_type"`
	LabID     string                 `json:"lab_id"`
	Variant   string                 `json:"variant"`
	SessionID string                 `json:"session_id"`
	Timestamp time.Time              `json:"timestamp"`
	Metadata  map[string]interface{} `json:"metadata"`
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

func main() {
	projectID := os.Getenv("PROJECT_ID")
	environment := os.Getenv("ENVIRONMENT")
	_ = os.Getenv("FIRESTORE_DATABASE")
	disableFirestore := strings.EqualFold(os.Getenv("DISABLE_FIRESTORE"), "true")

	if projectID == "" {
		log.Fatal("PROJECT_ID environment variable is required")
	}

	// Initialize Firestore client unless disabled for local mode
	var client *firestore.Client
	if !disableFirestore {
		ctx := context.Background()
		
		// Check for Firebase service account credentials
		firebaseServiceAccount := os.Getenv("FIREBASE_SERVICE_ACCOUNT_KEY")
		var opts []option.ClientOption
		
		if firebaseServiceAccount != "" {
			// Use credentials from environment variable (JSON string)
			log.Printf("🔑 Loading Firestore credentials from FIREBASE_SERVICE_ACCOUNT_KEY")
			opts = append(opts, option.WithCredentialsJSON([]byte(firebaseServiceAccount)))
		} else {
			log.Printf("⚠️  No FIREBASE_SERVICE_ACCOUNT_KEY provided, using application default credentials")
		}
		
		c, err := firestore.NewClient(ctx, projectID, opts...)
		if err != nil {
			log.Printf("Firestore disabled due to init error (running in local mode): %v", err)
		} else {
			client = c
			defer client.Close()
			log.Printf("✅ Firestore client initialized successfully")
		}
	} else {
		log.Printf("DISABLE_FIRESTORE=true detected; running analytics in local mode without Firestore")
	}

	service := &AnalyticsService{
		firestoreClient: client,
		projectID:       projectID,
		environment:     environment,
	}

	// Setup routes
	r := mux.NewRouter()

	// Progress tracking endpoints
	r.HandleFunc("/api/progress", service.handleProgress).Methods("POST")
	r.HandleFunc("/api/progress/{session_id}", service.handleGetProgress).Methods("GET")
	r.HandleFunc("/api/completion", service.handleCompletion).Methods("POST")

	// Analytics endpoints
	r.HandleFunc("/api/analytics/event", service.handleAnalyticsEvent).Methods("POST")
	r.HandleFunc("/api/analytics/summary", service.handleAnalyticsSummary).Methods("GET")
	r.HandleFunc("/api/analytics/lab/{lab_id}", service.handleLabAnalytics).Methods("GET")

	// SEO endpoints
	r.HandleFunc("/api/seo/lab/{lab_id}", service.handleLabMetadata).Methods("GET")
	r.HandleFunc("/api/seo/sitemap", service.handleSitemap).Methods("GET")
	r.HandleFunc("/api/seo/structured-data", service.handleStructuredData).Methods("GET")

	// Health check
	r.HandleFunc("/health", service.handleHealth).Methods("GET")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Analytics service starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func (s *AnalyticsService) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":      "healthy",
		"service":     "analytics",
		"environment": s.environment,
	})
}

func (s *AnalyticsService) handleProgress(w http.ResponseWriter, r *http.Request) {
	var progress ProgressData
	if err := json.NewDecoder(r.Body).Decode(&progress); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	progress.LastUpdated = time.Now()

	if s.firestoreClient != nil {
		ctx := context.Background()
		_, err := s.firestoreClient.Collection("user_progress").Doc(progress.SessionID).Set(ctx, progress)
		if err != nil {
			log.Printf("Error saving progress: %v", err)
			http.Error(w, "Failed to save progress", http.StatusInternalServerError)
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

func (s *AnalyticsService) handleGetProgress(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	sessionID := vars["session_id"]

	if s.firestoreClient == nil {
		http.Error(w, "Progress not available in local mode", http.StatusNotFound)
		return
	}
	ctx := context.Background()
	doc, err := s.firestoreClient.Collection("user_progress").Doc(sessionID).Get(ctx)
	if err != nil {
		http.Error(w, "Progress not found", http.StatusNotFound)
		return
	}
	var progress ProgressData
	if err := doc.DataTo(&progress); err != nil {
		http.Error(w, "Failed to parse progress", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(progress)
}

func (s *AnalyticsService) handleCompletion(w http.ResponseWriter, r *http.Request) {
	var completion map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&completion); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Record completion event
	event := AnalyticsEvent{
		EventType: "lab_completed",
		LabID:     completion["lab_id"].(string),
		Variant:   completion["variant"].(string),
		SessionID: completion["session_id"].(string),
		Timestamp: time.Now(),
		Metadata:  completion,
	}

	if s.firestoreClient != nil {
		ctx := context.Background()
		_, _, err := s.firestoreClient.Collection("analytics").Add(ctx, event)
		if err != nil {
			log.Printf("Error recording completion: %v", err)
			http.Error(w, "Failed to record completion", http.StatusInternalServerError)
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

func (s *AnalyticsService) handleAnalyticsEvent(w http.ResponseWriter, r *http.Request) {
	var event AnalyticsEvent
	if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	event.Timestamp = time.Now()

	if s.firestoreClient != nil {
		ctx := context.Background()
		_, _, err := s.firestoreClient.Collection("analytics").Add(ctx, event)
		if err != nil {
			log.Printf("Error recording analytics event: %v", err)
			http.Error(w, "Failed to record event", http.StatusInternalServerError)
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

func (s *AnalyticsService) handleAnalyticsSummary(w http.ResponseWriter, r *http.Request) {
	// This would query Firestore for analytics summary
	// For now, return a placeholder
	summary := map[string]interface{}{
		"total_events": 0,
		"unique_users": 0,
		"lab_stats":    map[string]interface{}{},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(summary)
}

func (s *AnalyticsService) handleLabAnalytics(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	labID := vars["lab_id"]

	// This would query Firestore for lab-specific analytics
	// For now, return a placeholder
	stats := map[string]interface{}{
		"lab_id":           labID,
		"total_visits":     0,
		"completion_rate":  0.0,
		"average_duration": 0,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}

func (s *AnalyticsService) handleLabMetadata(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	labID := vars["lab_id"]

	// This would query Firestore for lab metadata
	// For now, return a placeholder
	metadata := LabMetadata{
		LabID:       labID,
		Title:       "E-Skimming Lab",
		Description: "Interactive cybersecurity lab",
		Difficulty:  "intermediate",
		Duration:    "30 minutes",
		Topics:      []string{"cybersecurity", "web-security"},
		Variants:    []string{"base", "advanced"},
		URL:         fmt.Sprintf("https://labs.pcioasis.com/%s", labID),
		LastUpdated: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(metadata)
}

func (s *AnalyticsService) handleSitemap(w http.ResponseWriter, r *http.Request) {
	// Generate XML sitemap
	sitemap := `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://labs.pcioasis.com/</loc>
    <lastmod>2024-01-01T00:00:00Z</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>`

	w.Header().Set("Content-Type", "application/xml")
	w.Write([]byte(sitemap))
}

func (s *AnalyticsService) handleStructuredData(w http.ResponseWriter, r *http.Request) {
	structuredData := map[string]interface{}{
		"@context":    "https://schema.org",
		"@type":       "EducationalOccupationalProgram",
		"name":        "E-Skimming Security Labs",
		"description": "Interactive cybersecurity labs for learning e-skimming attacks",
		"provider": map[string]interface{}{
			"@type": "Organization",
			"name":  "PCI Oasis",
			"url":   "https://pcioasis.com",
		},
		"courseMode":       "online",
		"educationalLevel": "intermediate",
		"teaches":          []string{"Cybersecurity", "Web Security", "E-commerce Security"},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(structuredData)
}
