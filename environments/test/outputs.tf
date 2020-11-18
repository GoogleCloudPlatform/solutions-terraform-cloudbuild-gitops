output "storage" {
  value = "${module.storage.bucket}"
}

output "startup_script" {
  value = "${module.storage.startup-script}"


output "cf_sa" {
  value = "${module.cloudfunction.cf_sa}"
}

output "cf_clienteAgeValidator" {
  value = "${module.cloudfunction.cloudfunction_clientAgeVal}"
}