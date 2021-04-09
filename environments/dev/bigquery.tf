resource "google_bigquery_dataset" "data_warehouse" {
    project       = var.project
    dataset_id    = "dwh_us"
    friendly_name = "Data Warehouse (US)"
    description   = "Our main data warehouse located in the US"
    location      = "US"
    # default_table_expiration_ms = 1
    # default_partition_expiration_ms = 1
    delete_contents_on_destroy = true

    labels = {
        env = "dev"
    }
}

resource "google_bigquery_table" "default" {
  dataset_id = google_bigquery_dataset.data_warehouse.dataset_id
  table_id = "wikipedia_pageviews_2021"
  description = "Wikipedia pageviews from http://dumps.wikimedia.your.org/other/pageviews/, partitioned by date, clustered by (wiki, title). Source: bigquery-public-data.wikipedia"
  schema = file("schemas/pageviews_2021.schema.json")

  time_partitioning {
    type  = "DAY"
    field = "datehour"
    require_partition_filter = true
  }

  clustering = [ "wiki", "title" ]
}