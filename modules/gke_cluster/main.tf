resource "google_container_cluster" "cluster" {
  name                          = var.cluster_name
  description                   = "terraform-created gke cluster"
  location                      = var.region
  network                       = var.network
  subnetwork                    = var.subnetwork
  initial_node_count            = 1
  enable_shielded_nodes         = true
  enable_binary_authorization   = true
  
  private_cluster_config {
    enable_private_nodes      = true
    enable_private_endpoint   = false
    master_ipv4_cidr_block    = var.master_ipv4_cidr
  }
  
  node_config {
    shielded_instance_config {
        enable_integrity_monitoring = true 
        enable_secure_boot          = true
    }
  }
  
  timeouts {
    create = "30m"
    update = "40m"
  }
}