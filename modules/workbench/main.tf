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
    repository  = var.container
    tag         = var.tag
  }
  metadata = {
    terraform = "true"
  }
}

