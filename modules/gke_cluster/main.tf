resource "google_service_account" "default" {
  account_id   = "sa-${var.cluster_name}-gke-cluster"
  display_name = "sa-${var.cluster_name}-gke-cluster"
}

resource "google_container_cluster" "cluster" {
  name                          = var.cluster_name
  description                   = "terraform-created gke cluster"
  location                      = var.region
  network                       = var.network
  subnetwork                    = var.subnetwork

  remove_default_node_pool      = true
  initial_node_count            = 1
  
  enable_shielded_nodes         = true
  enable_binary_authorization   = true
  
  private_cluster_config {
    enable_private_nodes      = true
    enable_private_endpoint   = false
    master_ipv4_cidr_block    = var.master_ipv4_cidr
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.cluster.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-micro"

    shielded_instance_config {
        enable_integrity_monitoring = true 
        enable_secure_boot          = true
    }
    
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  
  timeouts {
    create = "30m"
    update = "40m"
  }
}