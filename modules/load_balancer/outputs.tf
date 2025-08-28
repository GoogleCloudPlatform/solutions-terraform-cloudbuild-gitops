output "external_ip" {
  value       = "${module.load_balancer.external_ip}"
}
