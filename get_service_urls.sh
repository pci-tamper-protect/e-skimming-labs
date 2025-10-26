#!/bin/bash
# Get all Cloud Run service URLs

echo "Getting lab service URLs..."
LAB1=$(gcloud run services describe lab-01-basic-magecart-prd --project=labs-prd --region=us-central1 --format="value(status.url)" 2>/dev/null)
LAB2=$(gcloud run services describe lab-02-dom-skimming-prd --project=labs-prd --region=us-central1 --format="value(status.url)" 2>/dev/null)
LAB3=$(gcloud run services describe lab-03-extension-hijacking-prd --project=labs-prd --region=us-central1 --format="value(status.url)" 2>/dev/null)

echo "LAB1_URL=$LAB1"
echo "LAB2_URL=$LAB2"
echo "LAB3_URL=$LAB3"

# C2 servers
LAB1_C2=$(gcloud run services describe lab-01-basic-magecart-prd --project=labs-prd --region=us-central1 --format="value(status.url)" 2>/dev/null)s/incident/monitor
LAB2_C2=$(gcloud run services describe lab-02-dom-skimming-prd --project=labs-prd --region=us-central1 --format="value(status.url)" 2>/dev/null)s/stolen-data
LAB3_C2=$(gcloud run services describe lab-03-extension-hijacking-prd --project=labs-prd --region=us-central1 --format="value(status.url)" 2>/dev/null)s/data-exfil

echo "LAB1_C2_URL=$LAB1_C2"
echo "LAB2_C2_URL=$LAB2_C2"
echo "LAB3_C2_URL=$LAB3_C2"
