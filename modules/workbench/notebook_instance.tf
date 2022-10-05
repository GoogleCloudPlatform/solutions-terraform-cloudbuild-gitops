resource "google_notebooks_instance" "test-notebook" {
  name               = "test-notebook"
  project            = "df-data-science-test"
  location           = "europe-west-4"
  machine_type       = "n1-standard-1" // n1-standard-1 $41.01 monthly estimate
  install_gpu_driver = false
  instance_owners    = ["olav@olavnymoen.com"]
  vm_image { // https://cloud.google.com/vertex-ai/docs/workbench/user-managed/images
    project      = "deeplearning-platform-release"
    image_family = "common-cpu-notebooks"
  }
  metadata = {
    terraform = "true"
  }
}
