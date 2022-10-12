# Creates the workbench instance

resource "google_notebooks_instance" "main" {
  name                  = var.model_name
  project               = var.project
  location              = "europe-west4-a"
  machine_type          = var.machine_type
  install_gpu_driver    = var.gpu_count == 0 ? false : true

  dynamic "accelerator_config" {
    for_each = var.gpu_count == 0 ? [] : [1]
    content {
      type             = var.gpu_type
      core_count       = var.gpu_count
    }
  }

  instance_owners       = var.instance_owners
  container_image {
    repository  = "gcr.io/deeplearning-platform-release/tf2-gpu.2-10"
    tag         = "latest"
  }
  metadata = {
    terraform = "true"
  }
}


resource "google_storage_bucket" "function_bucket" {
    name     = "${var.project}-function"
    location = "europe-west4"
}

# Generates an archive of the source code compressed as a .zip file.
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "../../cloud_fun_src"
  output_path = "/tmp/function.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "zip" {
  source        = data.archive_file.source.output_path
  content_type  = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name          = "src-${data.archive_file.source.output_md5}.zip"
  bucket        = google_storage_bucket.function_bucket.name
}

# Create the Cloud function triggered by a `Finalize` event on the bucket
resource "google_cloudfunctions_function" "function" {
  name                  = "function-trigger-on-gcs"
  runtime               = "python37"
  region                = "europe-west4"

  # Get the source code of the cloud function as a Zip compression
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.zip.name

  # Must match the function name in the cloud function `main.py` source code
  trigger_http          = true
}
