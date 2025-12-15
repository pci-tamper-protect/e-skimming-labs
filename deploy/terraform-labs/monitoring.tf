# Monitoring and Logging

# Note: Logging metrics are complex to configure correctly
# For now, we'll focus on the alert policy and dashboard

# Alert policy for high error rates
resource "google_monitoring_alert_policy" "labs_error_rate" {
  project      = local.labs_project_id
  display_name = "E-Skimming Labs High Error Rate"
  combiner     = "OR"

  conditions {
    display_name = "Error rate too high"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name:\"labs-\" AND metric.type=\"run.googleapis.com/request_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.1

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }
    }
  }

  notification_channels = [
    # Add notification channels here if needed
  ]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Dashboard for lab monitoring
resource "google_monitoring_dashboard" "labs_dashboard" {
  project       = local.labs_project_id
  dashboard_json = jsonencode({
    displayName = "E-Skimming Labs Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 12
          height = 4
          widget = {
            title = "Service Health"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name:\"labs-\" AND metric.type=\"run.googleapis.com/request_count\""
                      aggregation = {
                        alignmentPeriod  = "300s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
            }
          }
        }
      ]
    }
  })
}
