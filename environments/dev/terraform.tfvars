project="yash-innovation"
kubernetes_engine-create=true


kubernetes_engine-count=1


k8s_cluster_name="tf-gke-cluster1"

k8s_cluster_location="us-central1-a"


k8s_remove_default_node_pool=true

k8s_initial_node_count=1

k8s_username="clusterusername"


k8s_password="clusterspassword"

k8s_issue_client_certificate=false

k8s_pool_name="tf-node-pool"


k8s_pool_location="us-central1-a"


k8s_pool_node_count=1

k8s_pool_preemptible=true

k8s_pool_machine_type="e2-micro"


k8s_pool_disable-legacy-endpoints=true
k8s_pool_oauth_scopes= [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring"
    ]
