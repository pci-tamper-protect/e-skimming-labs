# Analytics Service

A shared service for tracking user progress, lab completion, and usage analytics
across all e-skimming labs.

## Features

- **Progress Tracking**: Track user progress through labs (optional, no login
  required)
- **Usage Analytics**: Collect anonymous usage statistics
- **Lab Completion**: Track which labs users have completed
- **Performance Metrics**: Monitor lab performance and user engagement
- **SEO Data**: Provide data for SEO integration

## API Endpoints

### Progress Tracking (Optional)

- `POST /api/progress` - Record user progress
- `GET /api/progress/{session_id}` - Get user progress
- `POST /api/completion` - Mark lab as completed

### Analytics

- `POST /api/analytics/event` - Record analytics event
- `GET /api/analytics/summary` - Get usage summary
- `GET /api/analytics/lab/{lab_id}` - Get lab-specific analytics

### SEO Integration

- `GET /api/seo/lab/{lab_id}` - Get lab metadata for SEO
- `GET /api/seo/sitemap` - Generate sitemap data
- `GET /api/seo/structured-data` - Get structured data for labs

## Data Models

### User Progress

```json
{
  "session_id": "uuid",
  "lab_id": "lab1-basic-magecart",
  "variant": "base",
  "progress": {
    "current_step": 3,
    "total_steps": 5,
    "completed_steps": [1, 2],
    "started_at": "2024-01-01T00:00:00Z",
    "last_activity": "2024-01-01T01:00:00Z"
  },
  "completion": {
    "completed": false,
    "completed_at": null,
    "score": null
  }
}
```

### Analytics Event

```json
{
  "event_type": "lab_started|lab_completed|page_view|error",
  "lab_id": "lab1-basic-magecart",
  "variant": "base",
  "session_id": "uuid",
  "timestamp": "2024-01-01T00:00:00Z",
  "metadata": {
    "user_agent": "Mozilla/5.0...",
    "ip_hash": "hashed_ip",
    "referrer": "https://pcioasis.com"
  }
}
```

## Environment Variables

- `PROJECT_ID`: GCP project ID
- `ENVIRONMENT`: Environment (prd, stg)
- `FIRESTORE_DATABASE`: Firestore database name
- `ANALYTICS_ENABLED`: Enable/disable analytics (default: true)
- `PROGRESS_TRACKING_ENABLED`: Enable/disable progress tracking (default: true)

## Deployment

The service is deployed as a Cloud Run service and automatically configured by
Terraform.
