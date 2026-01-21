#!/usr/bin/env python3
"""
Home Index Service - Displays discovered Cloud Run services
Uses ADC (Application Default Credentials) to query Cloud Run API
"""

import os
import json
from datetime import datetime
from flask import Flask, render_template_string
from google.auth import default
from google.auth.transport.requests import Request
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

app = Flask(__name__)

# HTML template for the home page
HOME_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E-Skimming Labs - Service Gateway</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 2rem;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            background: white;
            border-radius: 12px;
            padding: 2rem;
            margin-bottom: 2rem;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 {
            color: #667eea;
            margin-bottom: 0.5rem;
        }
        .header p {
            color: #666;
            font-size: 0.95rem;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }
        .stat-card {
            background: white;
            border-radius: 8px;
            padding: 1.5rem;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .stat-card h3 {
            color: #667eea;
            font-size: 2rem;
            margin-bottom: 0.5rem;
        }
        .stat-card p {
            color: #666;
            font-size: 0.9rem;
        }
        .services {
            background: white;
            border-radius: 12px;
            padding: 2rem;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .services h2 {
            color: #333;
            margin-bottom: 1.5rem;
            padding-bottom: 1rem;
            border-bottom: 2px solid #667eea;
        }
        .service-list {
            display: grid;
            gap: 1rem;
        }
        .service-item {
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 1.5rem;
            transition: all 0.3s ease;
        }
        .service-item:hover {
            border-color: #667eea;
            box-shadow: 0 4px 8px rgba(102, 126, 234, 0.2);
            transform: translateY(-2px);
        }
        .service-name {
            font-size: 1.25rem;
            font-weight: 600;
            color: #333;
            margin-bottom: 0.5rem;
        }
        .service-url {
            color: #667eea;
            text-decoration: none;
            font-size: 0.9rem;
            word-break: break-all;
        }
        .service-url:hover {
            text-decoration: underline;
        }
        .service-meta {
            display: flex;
            gap: 1rem;
            margin-top: 0.75rem;
            font-size: 0.85rem;
            color: #666;
        }
        .badge {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border-radius: 12px;
            font-size: 0.75rem;
            font-weight: 600;
            margin-top: 0.5rem;
        }
        .badge-traefik {
            background: #e8f5e9;
            color: #2e7d32;
        }
        .badge-project {
            background: #e3f2fd;
            color: #1976d2;
        }
        .error {
            background: #ffebee;
            border: 1px solid #f44336;
            border-radius: 8px;
            padding: 1.5rem;
            color: #c62828;
        }
        .loading {
            text-align: center;
            padding: 2rem;
            color: #666;
        }
        .refresh-info {
            text-align: center;
            margin-top: 1rem;
            color: #666;
            font-size: 0.85rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 E-Skimming Labs Service Gateway</h1>
            <p>Traefik Gateway - Discovered Cloud Run Services</p>
        </div>

        {% if error %}
        <div class="error">
            <h3>⚠️ Error Loading Services</h3>
            <p>{{ error }}</p>
            <p style="margin-top: 1rem; font-size: 0.9rem;">
                <strong>Tip:</strong> Ensure ADC credentials are configured:<br>
                <code>gcloud auth application-default login</code>
            </p>
        </div>
        {% elif services %}
        <div class="stats">
            <div class="stat-card">
                <h3>{{ total_services }}</h3>
                <p>Total Services</p>
            </div>
            <div class="stat-card">
                <h3>{{ traefik_enabled }}</h3>
                <p>Traefik Enabled</p>
            </div>
            <div class="stat-card">
                <h3>{{ projects|length }}</h3>
                <p>Projects</p>
            </div>
            <div class="stat-card">
                <h3>{{ region }}</h3>
                <p>Region</p>
            </div>
        </div>

        <div class="services">
            <h2>📋 Discovered Services</h2>
            <div class="service-list">
                {% for service in services %}
                <div class="service-item">
                    <div class="service-name">{{ service.name }}</div>
                    <a href="{{ service.url }}" target="_blank" class="service-url">{{ service.url }}</a>
                    <div class="service-meta">
                        <span><strong>Project:</strong> {{ service.project_id }}</span>
                        <span><strong>Region:</strong> {{ service.region }}</span>
                    </div>
                    {% if service.traefik_enabled %}
                    <span class="badge badge-traefik">✓ Traefik Enabled</span>
                    {% endif %}
                    <span class="badge badge-project">{{ service.project_id }}</span>
                </div>
                {% endfor %}
            </div>
        </div>
        {% else %}
        <div class="loading">
            <p>🔍 No services discovered yet...</p>
            <p style="margin-top: 1rem; font-size: 0.9rem;">
                Services with <code>traefik.enable=true</code> label will appear here.
            </p>
        </div>
        {% endif %}

        <div class="refresh-info">
            <p>Last updated: {{ last_updated }}</p>
            <p>Refresh this page to see latest services</p>
        </div>
    </div>
</body>
</html>
"""


def get_cloud_run_client():
    """Initialize Cloud Run API client using ADC"""
    try:
        # Use Application Default Credentials
        # ADC will look for credentials in:
        # 1. GOOGLE_APPLICATION_CREDENTIALS env var (service account key file)
        # 2. gcloud application-default credentials (~/.config/gcloud/application_default_credentials.json)
        # 3. GCE/Cloud Run metadata server (in production)
        # 
        # In Docker, the gcloud config is mounted at /home/appuser/.config/gcloud
        # So ADC will find credentials there automatically
        credentials, project = default()
        
        # Build Cloud Run API client
        service = build('run', 'v1', credentials=credentials)
        return service, project
    except Exception as e:
        app.logger.error(f"Failed to initialize Cloud Run client: {e}")
        import traceback
        app.logger.error(traceback.format_exc())
        return None, None


def list_all_services(project_ids, region):
    """List all Cloud Run services from specified projects"""
    service, _ = get_cloud_run_client()
    if not service:
        return None, "Failed to initialize Cloud Run API client"
    
    all_services = []
    errors = []
    
    for project_id in project_ids:
        try:
            parent = f"projects/{project_id}/locations/{region}"
            request = service.projects().locations().services().list(parent=parent)
            
            while request is not None:
                response = request.execute()
                
                if 'items' in response:
                    for svc in response['items']:
                        service_name = svc.get('metadata', {}).get('name', 'unknown')
                        service_url = svc.get('status', {}).get('url', '')
                        
                        # Check for traefik.enable label (check both service-level and template labels)
                        labels = svc.get('metadata', {}).get('labels', {})
                        if not labels and 'spec' in svc:
                            template_meta = svc.get('spec', {}).get('template', {}).get('metadata', {})
                            labels = template_meta.get('labels', {})
                        
                        traefik_enabled = labels.get('traefik.enable') == 'true' or labels.get('traefik_enable') == 'true'
                        
                        all_services.append({
                            'name': service_name,
                            'url': service_url,
                            'project_id': project_id,
                            'region': region,
                            'traefik_enabled': traefik_enabled,
                            'labels': labels
                        })
                
                # Check for next page
                request = service.projects().locations().services().list_next(request, response)
                
        except HttpError as e:
            error_msg = f"Error querying {project_id}: {e.content.decode() if hasattr(e, 'content') else str(e)}"
            errors.append(error_msg)
            app.logger.error(error_msg)
        except Exception as e:
            error_msg = f"Unexpected error querying {project_id}: {str(e)}"
            errors.append(error_msg)
            app.logger.error(error_msg)
    
    if errors and not all_services:
        return None, "; ".join(errors)
    
    # Sort services: traefik-enabled first, then by name
    all_services.sort(key=lambda x: (not x['traefik_enabled'], x['name'].lower()))
    
    return all_services, None


@app.route('/')
def home():
    """Home page showing discovered Cloud Run services"""
    # Get configuration from environment
    project_ids = os.getenv('LABS_PROJECT_ID', 'labs-stg').split(',')
    if os.getenv('HOME_PROJECT_ID'):
        project_ids.append(os.getenv('HOME_PROJECT_ID'))
    project_ids = [p.strip() for p in project_ids if p.strip()]
    
    region = os.getenv('REGION', 'us-central1')
    
    # Query Cloud Run services
    services, error = list_all_services(project_ids, region)
    
    if error:
        return render_template_string(
            HOME_TEMPLATE,
            error=error,
            last_updated=datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
        )
    
    # Calculate stats
    total_services = len(services) if services else 0
    traefik_enabled = sum(1 for s in services if s['traefik_enabled']) if services else 0
    projects = list(set(s['project_id'] for s in services)) if services else []
    
    return render_template_string(
        HOME_TEMPLATE,
        services=services or [],
        total_services=total_services,
        traefik_enabled=traefik_enabled,
        projects=projects,
        region=region,
        last_updated=datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
    )


@app.route('/health')
def health():
    """Health check endpoint"""
    return {'status': 'healthy', 'service': 'home-index'}, 200


if __name__ == '__main__':
    port = int(os.getenv('PORT', '8080'))
    app.run(host='0.0.0.0', port=port, debug=False)
