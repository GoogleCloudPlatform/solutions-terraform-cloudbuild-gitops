# Workbench instance

resource "google_notebooks_instance" "main" {
  name                  = var.model_name
  project               = var.project
  location              = "europe-west4-a"
  machine_type          = var.machine_type
  install_gpu_driver    = var.gpu_count == 0 ? false : true
  accelerator_config    = var.gpu_count == 0 ? null : {
    type                = var.gpu_type
    core_count          = var.gpu_count
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
