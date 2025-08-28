# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "google_project_service" "cloud_monitoring_api" {
  project = var.project_id
  service = "monitoring.googleapis.com"
}

resource "google_monitoring_dashboard" "denials_dashboard" {
  project        = var.project_id
  dashboard_json = <<EOF
{
  "displayName": "VPC SC denials",
  "dashboardFilters": [],
  "mosaicLayout": {
    "columns": 48,
    "tiles": [
      {
        "width": 24,
        "height": 16,
        "widget": {
          "singleViewGroup": {}
        }
      },
      {
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Violations by project [ENFORCED]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"projectId\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" metric.label.\"dryRun\"!=\"true\""
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Violations by project [DRY RUN]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "minAlignmentPeriod": "60s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"projectId\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" metric.label.\"dryRun\"=\"true\""
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "xPos": 24,
        "width": 24,
        "height": 16,
        "widget": {
          "singleViewGroup": {}
        }
      },
      {
        "xPos": 24,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Top identities (by number of denials) [ENFORCED]",
          "timeSeriesTable": {
            "columnSettings": [
              {
                "column": "identity",
                "visible": true
              },
              {
                "column": "value",
                "visible": true
              }
            ],
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "timeSeriesQuery": {
                  "outputFullDuration": true,
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"identity\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" metric.label.\"dryRun\"!=\"true\"",
                    "pickTimeSeriesFilter": {
                      "direction": "TOP",
                      "numTimeSeries": 30,
                      "rankingMethod": "METHOD_SUM"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "BAR"
          }
        }
      },
      {
        "xPos": 24,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Top identities (by number of denials) [DRY RUN]",
          "timeSeriesTable": {
            "columnSettings": [
              {
                "column": "identity",
                "visible": true
              },
              {
                "column": "value",
                "visible": true
              }
            ],
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "timeSeriesQuery": {
                  "outputFullDuration": true,
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"identity\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" metric.label.\"dryRun\"=\"true\"",
                    "pickTimeSeriesFilter": {
                      "direction": "TOP",
                      "numTimeSeries": 30,
                      "rankingMethod": "METHOD_SUM"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "BAR"
          }
        }
      },
      {
        "yPos": 16,
        "width": 24,
        "height": 16,
        "widget": {
          "singleViewGroup": {}
        }
      },
      {
        "yPos": 16,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Top projects (by number of denials) [ENFORCED]",
          "timeSeriesTable": {
            "columnSettings": [
              {
                "column": "projectId",
                "visible": true
              },
              {
                "column": "value",
                "visible": true
              }
            ],
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "timeSeriesQuery": {
                  "outputFullDuration": true,
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"projectId\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" resource.type=\"logging_bucket\" metric.label.\"dryRun\"!=\"true\"",
                    "pickTimeSeriesFilter": {
                      "direction": "TOP",
                      "numTimeSeries": 30,
                      "rankingMethod": "METHOD_SUM"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "BAR"
          }
        }
      },
      {
        "yPos": 16,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Top projects (by number of denials) [DRY RUN]",
          "timeSeriesTable": {
            "columnSettings": [
              {
                "column": "projectId",
                "visible": true
              },
              {
                "column": "value",
                "visible": true
              }
            ],
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "timeSeriesQuery": {
                  "outputFullDuration": true,
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"projectId\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" resource.type=\"logging_bucket\" metric.label.\"dryRun\"=\"true\"",
                    "pickTimeSeriesFilter": {
                      "direction": "TOP",
                      "numTimeSeries": 30,
                      "rankingMethod": "METHOD_SUM"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "BAR"
          }
        }
      },
      {
        "xPos": 24,
        "yPos": 16,
        "width": 24,
        "height": 16,
        "widget": {
          "singleViewGroup": {}
        }
      },
      {
        "xPos": 24,
        "yPos": 16,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Top perimeters (by number of denials) [ENFORCED]",
          "timeSeriesTable": {
            "columnSettings": [
              {
                "column": "perimeter",
                "visible": true
              },
              {
                "column": "value",
                "visible": true
              }
            ],
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "timeSeriesQuery": {
                  "outputFullDuration": true,
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"perimeter\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" metric.label.\"dryRun\"!=\"true\"",
                    "pickTimeSeriesFilter": {
                      "direction": "TOP",
                      "numTimeSeries": 30,
                      "rankingMethod": "METHOD_SUM"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "BAR"
          }
        }
      },
      {
        "xPos": 24,
        "yPos": 16,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Top perimeters (by number of denials) [DRY RUN]",
          "timeSeriesTable": {
            "columnSettings": [
              {
                "column": "perimeter",
                "visible": true
              },
              {
                "column": "value",
                "visible": true
              }
            ],
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "timeSeriesQuery": {
                  "outputFullDuration": true,
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"perimeter\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" metric.label.\"dryRun\"=\"true\"",
                    "pickTimeSeriesFilter": {
                      "direction": "TOP",
                      "numTimeSeries": 30,
                      "rankingMethod": "METHOD_SUM"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "BAR"
          }
        }
      },
      {
        "xPos": 24,
        "yPos": 32,
        "width": 24,
        "height": 16,
        "widget": {
          "singleViewGroup": {}
        }
      },
      {
        "xPos": 24,
        "yPos": 32,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Top methods (by number of denials) [ENFORCED]",
          "timeSeriesTable": {
            "columnSettings": [
              {
                "column": "method",
                "visible": true
              },
              {
                "column": "value",
                "visible": true
              }
            ],
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "timeSeriesQuery": {
                  "outputFullDuration": true,
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"method\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" resource.type=\"logging_bucket\" metric.label.\"dryRun\"!=\"true\"",
                    "pickTimeSeriesFilter": {
                      "direction": "TOP",
                      "numTimeSeries": 30,
                      "rankingMethod": "METHOD_SUM"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "BAR"
          }
        }
      },
      {
        "xPos": 24,
        "yPos": 32,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Top methods (by number of denials) [DRY RUN]",
          "timeSeriesTable": {
            "columnSettings": [
              {
                "column": "method",
                "visible": true
              },
              {
                "column": "value",
                "visible": true
              }
            ],
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "timeSeriesQuery": {
                  "outputFullDuration": true,
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"method\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" resource.type=\"logging_bucket\" metric.label.\"dryRun\"=\"true\"",
                    "pickTimeSeriesFilter": {
                      "direction": "TOP",
                      "numTimeSeries": 30,
                      "rankingMethod": "METHOD_SUM"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "BAR"
          }
        }
      },
      {
        "yPos": 32,
        "width": 24,
        "height": 16,
        "widget": {
          "singleViewGroup": {}
        }
      },
      {
        "yPos": 32,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Top services (by number of denials) [ENFORCED]",
          "timeSeriesTable": {
            "columnSettings": [
              {
                "column": "service",
                "visible": true
              },
              {
                "column": "value",
                "visible": true
              }
            ],
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "timeSeriesQuery": {
                  "outputFullDuration": true,
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"service\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" metric.label.\"dryRun\"!=\"true\"",
                    "pickTimeSeriesFilter": {
                      "direction": "TOP",
                      "numTimeSeries": 30,
                      "rankingMethod": "METHOD_SUM"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "BAR"
          }
        }
      },
      {
        "yPos": 32,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "Top services (by number of denials) [DRY RUN]",
          "timeSeriesTable": {
            "columnSettings": [
              {
                "column": "service",
                "visible": true
              },
              {
                "column": "value",
                "visible": true
              }
            ],
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "timeSeriesQuery": {
                  "outputFullDuration": true,
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": ["metric.label.\"service\""],
                      "perSeriesAligner": "ALIGN_SUM"
                    },
                    "filter": "metric.type=\"logging.googleapis.com/user/${var.log_based_metric_name}\" metric.label.\"dryRun\"=\"true\"",
                    "pickTimeSeriesFilter": {
                      "direction": "TOP",
                      "numTimeSeries": 30,
                      "rankingMethod": "METHOD_SUM"
                    }
                  }
                }
              }
            ],
            "metricVisualization": "BAR"
          }
        }
      }
    ]
  },
  "labels": {}
}
EOF
  depends_on     = [google_project_service.cloud_monitoring_api]
}
