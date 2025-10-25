# SEO Service

A shared service for SEO integration between the e-skimming labs and the main
pcioasis.com website.

## Features

- **Sitemap Generation**: Generate XML sitemaps for labs
- **Structured Data**: Provide JSON-LD structured data for search engines
- **Meta Tags**: Generate meta tags for lab pages
- **Cross-Domain Integration**: Integrate with main pcioasis.com for SEO
  benefits
- **Analytics Integration**: Provide SEO-relevant analytics data

## API Endpoints

### Sitemap

- `GET /api/sitemap.xml` - Generate XML sitemap
- `GET /api/sitemap/labs.xml` - Labs-specific sitemap
- `GET /api/sitemap/variants.xml` - Lab variants sitemap

### Structured Data

- `GET /api/structured-data/lab/{lab_id}` - Get lab structured data
- `GET /api/structured-data/collection` - Get collection structured data
- `GET /api/structured-data/organization` - Get organization structured data

### Meta Tags

- `GET /api/meta/lab/{lab_id}` - Get lab meta tags
- `GET /api/meta/variant/{lab_id}/{variant}` - Get variant meta tags

### Integration

- `GET /api/integration/pcioasis` - Data for pcioasis.com integration
- `POST /api/integration/sync` - Sync with main site
- `GET /api/integration/status` - Integration status

## SEO Strategy

### Cross-Domain Benefits

1. **Internal Linking**: Labs link back to main pcioasis.com
2. **Content Syndication**: Lab content appears on main site
3. **Domain Authority**: Share domain authority between sites
4. **Structured Data**: Unified structured data across domains

### Content Integration

- Lab descriptions appear on main site
- Lab completion certificates link to main site
- Cross-promotion between main site and labs
- Unified search experience

## Data Models

### Lab Metadata

```json
{
  "lab_id": "lab1-basic-magecart",
  "title": "Basic Magecart Attack Lab",
  "description": "Learn the fundamentals of Magecart attacks...",
  "difficulty": "beginner",
  "duration": "30 minutes",
  "topics": ["magecart", "javascript", "e-commerce"],
  "variants": ["base", "obfuscated-base64", "event-listener", "websocket"],
  "url": "https://labs.pcioasis.com/lab1-basic-magecart",
  "last_updated": "2024-01-01T00:00:00Z"
}
```

### Structured Data (JSON-LD)

```json
{
  "@context": "https://schema.org",
  "@type": "EducationalOccupationalProgram",
  "name": "E-Skimming Security Labs",
  "description": "Interactive cybersecurity labs for learning e-skimming attacks",
  "provider": {
    "@type": "Organization",
    "name": "PCI Oasis",
    "url": "https://pcioasis.com"
  },
  "courseMode": "online",
  "educationalLevel": "intermediate",
  "teaches": ["Cybersecurity", "Web Security", "E-commerce Security"]
}
```

## Environment Variables

- `PROJECT_ID`: GCP project ID
- `ENVIRONMENT`: Environment (prd, stg)
- `MAIN_DOMAIN`: Main pcioasis.com domain
- `LABS_DOMAIN`: Labs domain (labs.pcioasis.com)
- `FIRESTORE_DATABASE`: Firestore database name

## Integration with pcioasis.com

### Methods

1. **API Integration**: Main site calls SEO service APIs
2. **Webhook Integration**: Labs notify main site of updates
3. **Shared Database**: Both sites access shared data
4. **CDN Integration**: Shared content delivery

### Benefits

- Improved search rankings for both domains
- Better user experience with cross-site navigation
- Unified analytics and tracking
- Enhanced content discovery
