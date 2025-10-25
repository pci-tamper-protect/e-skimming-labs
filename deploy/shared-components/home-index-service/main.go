package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

type Lab struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Difficulty  string `json:"difficulty"`
	URL         string `json:"url"`
	Status      string `json:"status"`
}

type HomePageData struct {
	Environment    string
	Domain         string
	LabsDomain     string
	MainDomain     string
	LabsProjectID  string
	Scheme         string
	Labs           []Lab
	MITREURL       string
	ThreatModelURL string
	CatalogInfo    *CatalogInfo
}

// CatalogInfo represents the catalog metadata
type CatalogInfo struct {
	PTP struct {
		Service struct {
			Name        string `yaml:"name"`
			Version     string `yaml:"version"`
			Environment string `yaml:"environment"`
		} `yaml:"service"`
		Git struct {
			CommitSHAShort string `yaml:"commit_sha_short"`
			CommitAuthor   string `yaml:"commit_author"`
			Branch         string `yaml:"branch"`
			CommitMessage  string `yaml:"commit_message"`
		} `yaml:"git"`
	} `yaml:"ptp"`
}

// loadCatalogInfo loads catalog information from catalog-info.yaml
func loadCatalogInfo() *CatalogInfo {
	data, err := os.ReadFile("/app/catalog-info.yaml")
	if err != nil {
		log.Printf("⚠️ Could not load catalog info: %v", err)
		return nil
	}

	var catalogInfo CatalogInfo
	if err := yaml.Unmarshal(data, &catalogInfo); err != nil {
		log.Printf("⚠️ Could not parse catalog info: %v", err)
		return nil
	}

	return &catalogInfo
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Load catalog information
	catalogInfo := loadCatalogInfo()
	if catalogInfo != nil {
		log.Printf("🚀 Starting %s v%s",
			catalogInfo.PTP.Service.Name,
			catalogInfo.PTP.Service.Version)
		log.Printf("🔗 Git commit: %s (%s) by %s",
			catalogInfo.PTP.Git.CommitSHAShort,
			catalogInfo.PTP.Git.Branch,
			catalogInfo.PTP.Git.CommitAuthor)
		if catalogInfo.PTP.Git.CommitMessage != "" {
			log.Printf("📝 Commit message: %s", catalogInfo.PTP.Git.CommitMessage)
		}
	} else {
		log.Printf("🚀 Starting E-Skimming Labs (catalog info not available)")
	}

	// Get environment variables
	environment := os.Getenv("ENVIRONMENT")
	domain := os.Getenv("DOMAIN")
	labsDomain := os.Getenv("LABS_DOMAIN")
	lab1Domain := os.Getenv("LAB1_DOMAIN")
	lab2Domain := os.Getenv("LAB2_DOMAIN")
	lab3Domain := os.Getenv("LAB3_DOMAIN")
	mainDomain := os.Getenv("MAIN_DOMAIN")
	labsProjectID := os.Getenv("LABS_PROJECT_ID")

	// Set default values
	if domain == "" {
		domain = "labs.pcioasis.com"
	}
	if labsDomain == "" {
		labsDomain = "labs.pcioasis.com"
	}
	if lab1Domain == "" {
		lab1Domain = labsDomain
	}
	if lab2Domain == "" {
		lab2Domain = labsDomain
	}
	if lab3Domain == "" {
		lab3Domain = labsDomain
	}
	if mainDomain == "" {
		mainDomain = "pcioasis.com"
	}
	if labsProjectID == "" {
		labsProjectID = "labs-prd"
	}

	// Choose http for local/dev, https otherwise
	isLocal := strings.EqualFold(environment, "local") || strings.Contains(domain, "localhost") || strings.Contains(labsDomain, "localhost")
	scheme := "https"
	if isLocal {
		scheme = "http"
	}

	// Define available labs with detailed descriptions
	labs := []Lab{
		{
			ID:          "lab1-basic-magecart",
			Name:        "Basic Magecart Attack",
			Description: "Learn the fundamentals of payment card skimming attacks through JavaScript injection. Understand how attackers compromise e-commerce sites, intercept form submissions, and exfiltrate credit card data. Practice detection using browser DevTools and implement basic defensive measures.",
			Difficulty:  "Beginner",
			URL:         fmt.Sprintf("%s://%s", scheme, lab1Domain),
			Status:      "Available",
		},
		{
			ID:          "lab2-dom-skimming",
			Name:        "DOM-Based Skimming",
			Description: "Master advanced DOM manipulation techniques for stealthy payment data capture. Learn real-time field monitoring, dynamic form injection, Shadow DOM abuse, and DOM tree manipulation. Understand how attackers bypass traditional detection methods.",
			Difficulty:  "Intermediate",
			URL:         fmt.Sprintf("%s://%s", scheme, lab2Domain),
			Status:      "Available",
		},
		{
			ID:          "lab3-extension-hijacking",
			Name:        "Browser Extension Hijacking",
			Description: "Explore sophisticated browser extension-based attacks that exploit privileged APIs and persistent access. Learn about content script injection, background script persistence, cross-origin communication, and supply chain attacks through malicious extensions.",
			Difficulty:  "Advanced",
			URL:         fmt.Sprintf("%s://%s", scheme, lab3Domain),
			Status:      "Available",
		},
	}

	// Create home page data
	homeData := HomePageData{
		Environment:    environment,
		Domain:         domain,
		LabsDomain:     labsDomain,
		MainDomain:     mainDomain,
		LabsProjectID:  labsProjectID,
		Scheme:         scheme,
		Labs:           labs,
		MITREURL:       fmt.Sprintf("%s://%s/mitre-attack", scheme, domain),
		ThreatModelURL: fmt.Sprintf("%s://%s/threat-model", scheme, domain),
	}

	// Define routes
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		serveHomePage(w, r, homeData)
	})

	http.HandleFunc("/mitre-attack", func(w http.ResponseWriter, r *http.Request) {
		serveMITREPage(w, r)
	})

	http.HandleFunc("/threat-model", func(w http.ResponseWriter, r *http.Request) {
		serveThreatModelPage(w, r)
	})

	http.HandleFunc("/api/labs", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(labs)
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	log.Printf("Starting server on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func serveHomePage(w http.ResponseWriter, r *http.Request, data HomePageData) {
	tmpl := `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E-Skimming Labs - Interactive Training Platform</title>
    <meta name="description" content="Interactive e-skimming attack labs for cybersecurity training and awareness">

    <!-- SEO Meta Tags -->
    <meta name="robots" content="index, follow">
    <meta name="keywords" content="e-skimming, cybersecurity, training, labs, payment security">
    <link rel="canonical" href="{{.Scheme}}://{{.Domain}}/">

    <!-- Open Graph -->
    <meta property="og:title" content="E-Skimming Labs - Interactive Training Platform">
    <meta property="og:description" content="Interactive e-skimming attack labs for cybersecurity training and awareness">
    <meta property="og:url" content="{{.Scheme}}://{{.Domain}}/">
    <meta property="og:type" content="website">

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="E-Skimming Labs - Interactive Training Platform">
    <meta name="twitter:description" content="Interactive e-skimming attack labs for cybersecurity training and awareness">

    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap');

        :root {
            --bg-primary: #0a0e27;
            --bg-secondary: #121733;
            --bg-tertiary: #1a1f3a;
            --bg-card: #1e2440;
            --bg-hover: #252b4a;

            --text-primary: #ffffff;
            --text-secondary: #b8c5db;
            --text-muted: #8b9dc3;

            --accent-red: #ff6b6b;
            --accent-orange: #ff922b;
            --accent-green: #51cf66;
            --accent-blue: #748ffc;
            --accent-purple: #b197fc;
            --accent-pink: #e64980;
            --accent-yellow: #ffd43b;

            --border-color: #2a3f5f;
            --shadow-sm: 0 2px 4px rgba(0,0,0,0.2);
            --shadow-md: 0 4px 12px rgba(0,0,0,0.3);
            --shadow-lg: 0 8px 24px rgba(0,0,0,0.4);

            --gradient-1: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            --gradient-2: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            --gradient-3: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.6;
            overflow-x: hidden;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 20px;
        }

        /* Header */
        .header {
            background: var(--bg-secondary);
            border-bottom: 1px solid var(--border-color);
            padding: 20px 0;
            position: sticky;
            top: 0;
            z-index: 100;
        }

        .header-content {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .logo {
            font-size: 24px;
            font-weight: 700;
            color: var(--accent-blue);
            text-decoration: none;
        }

        .nav-tabs {
            display: flex;
            gap: 20px;
        }

        .nav-tab {
            padding: 10px 20px;
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            color: var(--text-secondary);
            text-decoration: none;
            transition: all 0.3s ease;
            font-weight: 500;
        }

        .nav-tab:hover {
            background: var(--bg-hover);
            color: var(--text-primary);
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }

        .nav-tab.active {
            background: var(--gradient-1);
            color: var(--text-primary);
            border-color: transparent;
        }

        /* Hero Section */
        .hero {
            padding: 80px 0;
            text-align: center;
            background: var(--gradient-1);
            margin-bottom: 60px;
        }

        .hero h1 {
            font-size: 48px;
            font-weight: 800;
            margin-bottom: 20px;
            background: linear-gradient(135deg, #fff 0%, #e0e0e0 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .hero p {
            font-size: 20px;
            color: rgba(255, 255, 255, 0.9);
            max-width: 600px;
            margin: 0 auto;
        }

        /* Labs Section */
        .labs-section {
            padding: 60px 0;
        }

        .section-title {
            font-size: 36px;
            font-weight: 700;
            text-align: center;
            margin-bottom: 20px;
            color: var(--text-primary);
        }

        .section-subtitle {
            font-size: 18px;
            color: var(--text-secondary);
            text-align: center;
            margin-bottom: 50px;
            max-width: 600px;
            margin-left: auto;
            margin-right: auto;
        }

        .labs-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 30px;
            margin-bottom: 60px;
        }

        .lab-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 30px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .lab-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: var(--gradient-2);
        }

        .lab-card:hover {
            transform: translateY(-5px);
            box-shadow: var(--shadow-lg);
            border-color: var(--accent-blue);
        }

        .lab-title {
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 15px;
            color: var(--text-primary);
        }

        .lab-description {
            color: var(--text-secondary);
            margin-bottom: 20px;
            line-height: 1.6;
        }

        .lab-meta {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 25px;
        }

        .difficulty {
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }

        .difficulty.beginner {
            background: rgba(81, 207, 102, 0.2);
            color: var(--accent-green);
        }

        .difficulty.intermediate {
            background: rgba(255, 210, 59, 0.2);
            color: var(--accent-yellow);
        }

        .difficulty.advanced {
            background: rgba(255, 107, 107, 0.2);
            color: var(--accent-red);
        }

        .lab-status {
            font-size: 14px;
            color: var(--accent-green);
            font-weight: 500;
        }

        .lab-button {
            display: inline-block;
            padding: 12px 24px;
            background: var(--gradient-1);
            color: var(--text-primary);
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            transition: all 0.3s ease;
            width: 100%;
            text-align: center;
        }

        .lab-button:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }

        /* Resources Section */
        .resources-section {
            padding: 60px 0;
            background: var(--bg-secondary);
            border-radius: 20px;
            margin: 60px 0;
        }

        .resources-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
        }

        .resource-card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 30px;
            text-align: center;
            transition: all 0.3s ease;
        }

        .resource-card:hover {
            transform: translateY(-5px);
            box-shadow: var(--shadow-lg);
            border-color: var(--accent-purple);
        }

        .resource-icon {
            font-size: 48px;
            margin-bottom: 20px;
        }

        .resource-title {
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 15px;
            color: var(--text-primary);
        }

        .resource-description {
            color: var(--text-secondary);
            margin-bottom: 25px;
            line-height: 1.6;
        }

        .resource-button {
            display: inline-block;
            padding: 12px 24px;
            background: var(--gradient-3);
            color: var(--text-primary);
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            transition: all 0.3s ease;
        }

        .resource-button:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }

        /* Footer */
        .footer {
            background: var(--bg-secondary);
            border-top: 1px solid var(--border-color);
            padding: 40px 0;
            text-align: center;
            color: var(--text-muted);
        }

        .footer a {
            color: var(--accent-blue);
            text-decoration: none;
        }

        .footer a:hover {
            text-decoration: underline;
        }

        /* Responsive */
        @media (max-width: 768px) {
            .hero h1 {
                font-size: 36px;
            }

            .hero p {
                font-size: 18px;
            }

            .nav-tabs {
                flex-direction: column;
                gap: 10px;
            }

            .labs-grid {
                grid-template-columns: 1fr;
            }

            .resources-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="container">
            <div class="header-content">
                <a href="/" class="logo">E-Skimming Labs</a>
                <nav class="nav-tabs">
                    <a href="/" class="nav-tab active">Home</a>
                    <a href="{{.MITREURL}}" class="nav-tab">MITRE ATT&CK</a>
                    <a href="{{.ThreatModelURL}}" class="nav-tab">Threat Model</a>
                </nav>
            </div>
        </div>
    </header>

    <main>
        <section class="hero">
            <div class="container">
                <h1>Interactive E-Skimming Labs</h1>
                <p>Hands-on cybersecurity training for understanding and defending against payment card skimming attacks</p>
            </div>
        </section>

        <section class="labs-section">
            <div class="container">
                <h2 class="section-title">Available Labs</h2>
                <p class="section-subtitle">Choose from our interactive labs designed to teach you about different e-skimming attack techniques and defense strategies.</p>

                <div class="labs-grid">
                    {{range .Labs}}
                    <div class="lab-card">
                        <h3 class="lab-title">{{.Name}}</h3>
                        <p class="lab-description">{{.Description}}</p>
                        <div class="lab-meta">
                            <span class="difficulty {{.Difficulty | lower}}">{{.Difficulty}}</span>
                            <span class="lab-status">{{.Status}}</span>
                        </div>
                        <a href="{{.URL}}" class="lab-button">Start Lab</a>
                    </div>
                    {{end}}
                </div>
            </div>
        </section>

        <section class="resources-section">
            <div class="container">
                <h2 class="section-title">Learning Resources</h2>
                <p class="section-subtitle">Explore our comprehensive resources to deepen your understanding of e-skimming attacks.</p>

                <div class="resources-grid">
                    <div class="resource-card">
                        <div class="resource-icon">🎯</div>
                        <h3 class="resource-title">MITRE ATT&CK Framework</h3>
                        <p class="resource-description">Explore the comprehensive MITRE ATT&CK matrix specifically tailored for e-skimming attacks and payment card fraud.</p>
                        <a href="{{.MITREURL}}" class="resource-button">View ATT&CK Matrix</a>
                    </div>

                    <div class="resource-card">
                        <div class="resource-icon">🔍</div>
                        <h3 class="resource-title">Interactive Threat Model</h3>
                        <p class="resource-description">Visualize attack vectors and understand the threat landscape with our interactive threat modeling tool.</p>
                        <a href="{{.ThreatModelURL}}" class="resource-button">Explore Threat Model</a>
                    </div>
                </div>
            </div>
        </section>
    </main>

    <footer class="footer">
        <div class="container">
            <p>&copy; 2024 E-Skimming Labs. Part of <a href="https://{{.MainDomain}}">PCI Oasis</a> cybersecurity training platform.</p>
        </div>
    </footer>

    <script>
        // Add smooth scrolling for anchor links
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                document.querySelector(this.getAttribute('href')).scrollIntoView({
                    behavior: 'smooth'
                });
            });
        });

        // Add loading states for lab buttons
        document.querySelectorAll('.lab-button').forEach(button => {
            button.addEventListener('click', function(e) {
                this.textContent = 'Loading...';
                this.style.opacity = '0.7';
            });
        });
    </script>
</body>
</html>`

	t, err := template.New("home").Funcs(template.FuncMap{
		"lower": strings.ToLower,
	}).Parse(tmpl)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	err = t.Execute(w, data)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

func serveMITREPage(w http.ResponseWriter, r *http.Request) {
	// Read the MITRE ATT&CK HTML file
	mitreHTML, err := os.ReadFile("/app/docs/mitre-attack-visual.html")
	if err != nil {
		http.Error(w, "MITRE ATT&CK page not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(mitreHTML)
}

func serveThreatModelPage(w http.ResponseWriter, r *http.Request) {
	// Read the Interactive Threat Model HTML file
	threatModelHTML, err := os.ReadFile("/app/docs/interactive-threat-model.html")
	if err != nil {
		http.Error(w, "Threat model page not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(threatModelHTML)
}

func serveLabsAPI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Get labs data with detailed descriptions
	labs := []Lab{
		{
			ID:          "lab1-basic-magecart",
			Name:        "Basic Magecart Attack",
			Description: "Learn the fundamentals of payment card skimming attacks through JavaScript injection. Understand how attackers compromise e-commerce sites, intercept form submissions, and exfiltrate credit card data. Practice detection using browser DevTools and implement basic defensive measures.",
			Difficulty:  "Beginner",
			URL:         "/lab1-basic-magecart",
			Status:      "Available",
		},
		{
			ID:          "lab2-dom-skimming",
			Name:        "DOM-Based Skimming",
			Description: "Master advanced DOM manipulation techniques for stealthy payment data capture. Learn real-time field monitoring, dynamic form injection, Shadow DOM abuse, and DOM tree manipulation. Understand how attackers bypass traditional detection methods.",
			Difficulty:  "Intermediate",
			URL:         "/lab2-dom-skimming",
			Status:      "Available",
		},
		{
			ID:          "lab3-extension-hijacking",
			Name:        "Browser Extension Hijacking",
			Description: "Explore sophisticated browser extension-based attacks that exploit privileged APIs and persistent access. Learn about content script injection, background script persistence, cross-origin communication, and supply chain attacks through malicious extensions.",
			Difficulty:  "Advanced",
			URL:         "/lab3-extension-hijacking",
			Status:      "Available",
		},
	}

	json.NewEncoder(w).Encode(labs)
}
