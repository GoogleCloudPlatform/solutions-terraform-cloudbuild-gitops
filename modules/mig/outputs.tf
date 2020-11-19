output "mig_ip" {
  value = "${google_compute_address.cap_mig_ip.address}"
}

output "mig_name" {
  value = "${google_compute_region_instance_group_manager.cap_mig.name}"
}