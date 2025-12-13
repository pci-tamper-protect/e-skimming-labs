# Monitoring and Logging

# Email notification channel
resource "google_monitoring_notification_channel" "email_alerts" {
  display_name = "E-Skimming Labs Alert Email"
  type         = "email"

  labels = {
    email_address = "alerts@pcioasis.com"
  }

  enabled = true
}

# Log-based metrics for lab usage
resource "google_logging_metric" "lab_access_count" {
  name        = "labs_access_count"
  description = "Number of lab page accesses"
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=~\"labs-.*\" AND httpRequest.requestUrl=~\"/lab[0-9]+.*\""

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    display_name = "Lab Access Count"

    # Label descriptors must match label_extractors
    labels {
      key         = "lab_id"
      value_type  = "STRING"
      description = "Lab identifier extracted from URL"
    }
    labels {
      key         = "method"
      value_type  = "STRING"
      description = "HTTP method"
    }
  }

  # value_extractor is only allowed for DISTRIBUTION value types
  # For INT64 counter metrics, we just count matching log entries

  label_extractors = {
    "lab_id" = "EXTRACT(httpRequest.requestUrl)"
    "method" = "EXTRACT(httpRequest.requestMethod)"
  }
}

# Alert policy for high error rates
resource "google_monitoring_alert_policy" "labs_error_rate" {
  display_name = "E-Skimming Labs High Error Rate"
  combiner     = "OR"

  conditions {
    display_name = "Error rate too high"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name:\"labs-.*\" AND metric.type=\"run.googleapis.com/request_count\""
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
    google_monitoring_notification_channel.email_alerts.id
  ]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Dashboard for lab monitoring
resource "google_monitoring_dashboard" "labs_dashboard" {
  dashboard_json = jsonencode({
    displayName = "E-Skimming Labs Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Lab Access Count"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "metric.type=\"logging.googleapis.com/user/labs_access_count\""
                      aggregation = {
                        alignmentPeriod  = "300s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Service Health"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name:\"labs-.*\" AND metric.type=\"run.googleapis.com/request_count\""
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

