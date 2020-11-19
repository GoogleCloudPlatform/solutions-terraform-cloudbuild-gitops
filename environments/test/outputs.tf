output "mds" {
  value = "${module.storage.mds}"
}

output "main_bucket" {
  value = "${module.storage.main_bucket}"
}

output "startup_script" {
  value = "${module.storage.startup-script}"
}

output "cf_sa" {
  value = "${module.sa.cf_sa}"
}

output "mig_sa" {
  value = "${module.sa.mig_sa}"
}

output "credditApprovalNotification" {
  value = "${module.pubsub.credditApprovalNotification}"
}

output "credditApprovalValidation" {
  value = "${module.pubsub.credditApprovalValidation}"
}

output "cf_clientAgeVal" {
  value = "${module.cloudfunction.cf_clientAgeVal}"
}

output "cf_duePayVal" {
  value = "${module.cloudfunction.cf_duePayVal}"
}

output "cf_effortRateNewCredVal" {
  value = "${module.cloudfunction.cf_effortRateNewCredVal}"
}

output "cf_effortRateTotalCredVal" {
  value = "${module.cloudfunction.cf_effortRateTotalCredVal}"
}

output "cf_jsonToBase64" {
  value = "${module.cloudfunction.cf_jsonToBase64}"
}

output "mig_ip" {
  value = "${module.mig.mig_ip}"
}

output "mig_name" {
  value = "${module.mig.mig_name}"
}