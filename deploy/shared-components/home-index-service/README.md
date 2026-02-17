# Home Index Service

The home index service provides the main landing page for the E-Skimming Labs
platform, featuring:

## Features

- **Interactive Lab Directory**: Lists all available labs with detailed
  descriptions
- **Blog**: Technical articles and lab writeups on e-skimming attack techniques
- **MITRE ATT&CK Integration**: Direct access to the MITRE ATT&CK matrix for
  e-skimming attacks
- **Threat Model Visualization**: Interactive threat modeling tool
- **Responsive Design**: Modern, mobile-friendly interface
- **SEO Optimized**: Structured data and meta tags for search engines

## Lab Descriptions

### Lab 1: Basic Magecart Attack (Beginner)

Learn the fundamentals of payment card skimming attacks through JavaScript
injection. Understand how attackers compromise e-commerce sites, intercept form
submissions, and exfiltrate credit card data. Practice detection using browser
DevTools and implement basic defensive measures.

### Lab 2: DOM-Based Skimming (Intermediate)

Master advanced DOM manipulation techniques for stealthy payment data capture.
Learn real-time field monitoring, dynamic form injection, Shadow DOM abuse, and
DOM tree manipulation. Understand how attackers bypass traditional detection
methods.

### Lab 3: Browser Extension Hijacking (Advanced)

Explore sophisticated browser extension-based attacks that exploit privileged
APIs and persistent access. Learn about content script injection, background
script persistence, cross-origin communication, and supply chain attacks through
malicious extensions.

## API Endpoints

- `GET /` - Main landing page
- `GET /blog` - Blog landing page with article index
- `GET /blog/understanding-magecart` - Magecart attack deep-dive (Lab 1 writeup)
- `GET /mitre-attack` - MITRE ATT&CK matrix page
- `GET /threat-model` - Interactive threat model
- `GET /lab-01-writeup` - Lab 1 technical writeup
- `GET /lab-02-writeup` - Lab 2 technical writeup
- `GET /lab-03-writeup` - Lab 3 technical writeup
- `GET /api/labs` - JSON API for lab information
- `GET /health` - Health check endpoint

## Environment Variables

- `PORT` - Server port (default: 8080)
- `ENVIRONMENT` - Deployment environment (stg/prd)
- `DOMAIN` - Primary domain for the service
- `LABS_DOMAIN` - Domain for individual labs
- `MAIN_DOMAIN` - Main pcioasis.com domain
- `LABS_PROJECT_ID` - Google Cloud project ID for labs

## Deployment

This service is deployed as part of the `labs-home-prd` project using Cloud Run.
The Docker image includes the MITRE ATT&CK and threat model HTML files from the
`docs/` directory, and blog HTML files from the service directory.

### Blog Files

Blog content is served from standalone HTML files:
- `blog-preview.html` - Blog landing page (served at `/blog`)
- `blog-post-preview.html` - Magecart article (served at `/blog/understanding-magecart`)

These are copied into the container via the Dockerfile.


