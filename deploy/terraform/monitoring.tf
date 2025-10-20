# Monitoring and Logging

# Log-based metrics for lab usage
resource "google_logging_metric" "lab_access_count" {
  name   = "labs_access_count"
  filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=~\"labs-.*\" AND httpRequest.requestUrl=~\"/lab[0-9]+.*\""

  metric_descriptor {
    metric_kind = "COUNTER"
    value_type  = "INT64"
    display_name = "Lab Access Count"
    description  = "Number of lab page accesses"
  }

  value_extractor = "EXTRACT(httpRequest.requestUrl)"
  
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
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=~\"labs-.*\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 0.1

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields = ["resource.labels.service_name"]
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
  dashboard_json = jsonencode({
    displayName = "E-Skimming Labs Dashboard"
    mosaicLayout = {
      tiles = [
        {
          width = 6
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
                        alignmentPeriod = "300s"
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
          width = 6
          height = 4
          widget = {
            title = "Service Health"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=~\"labs-.*\""
                      aggregation = {
                        alignmentPeriod = "300s"
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

