resource "google_container_cluster" "primary" {
  name                      = var.cluster_name
  description               = "terraform-created gke cluster"
  location                  = var.region
  network                   = var.network
  subnetwork                = var.subnetwork
  enable_shielded_nodes     = true
  enable_secure_boot        = true
  enable_private_nodes      = true
  enable_private_endpoint   = false

  initial_node_count = 3

  timeouts {
    create = "30m"
    update = "40m"
  }

  ip_allocation_policy {
      cluster_ipv4_cidr_block   = var.master_ipv4_cidr
  }

  binary_authorization {
      evaluation_mode           = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }
}
