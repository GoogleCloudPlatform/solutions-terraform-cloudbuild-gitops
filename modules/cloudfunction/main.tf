##### CLIENT AGE VALIDATION #####

data "archive_file" "client_age_validation_zip" {
  type        = "zip"
  source_dir  = "${path.module}/client_age_validation"
  output_path = "${path.module}/files/client_age_validation.zip"
}

# Storing zip to be used in the client_age_validation cf
resource "google_storage_bucket_object" "client_age_validation_obj" {
  name   = "cfs/client_age_validation.zip"
  bucket = "${var.mds}"
  source = "${data.archive_file.client_age_validation_zip.output_path}"
  depends_on = [data.archive_file.client_age_validation_zip]
}

# client_age_validation cf
resource "google_cloudfunctions_function" "client_age_validation_cf" {
 name                  = "client-age-validation"
 description           = "CF to validate the client age"
 available_memory_mb   = 128
 source_archive_bucket = "${var.mds}"
 source_archive_object = "${google_storage_bucket_object.client_age_validation_obj.name}"
 timeout               = 60
 entry_point           = "client_age_validation"
 ingress_settings      = "ALLOW_ALL"
 service_account_email = "${var.sa_email}"
 runtime               = "python38"
 trigger_http          = true
}

##### DUE PAYMENTS VALIDATION #####

data "archive_file" "due_payments_validation_zip" {
  type        = "zip"
  source_dir  = "${path.module}/due_payments_validation"
  output_path = "${path.module}/files/due_payments_validation.zip"
}

# Storing zip to be used in the due_payments_validation cf
resource "google_storage_bucket_object" "due_payments_validation_obj" {
  name   = "cfs/due_payments_validation.zip"
  bucket = "${var.mds}"
  source = "${data.archive_file.due_payments_validation_zip.output_path}"
  depends_on = [data.archive_file.due_payments_validation_zip]
}

# due_payments_validation cf
resource "google_cloudfunctions_function" "due_payments_validation_cf" {
 name                  = "due-payments-validation"
 description           = "CF to validate due payments"
 available_memory_mb   = 128
 source_archive_bucket = "${var.mds}"
 source_archive_object = "${google_storage_bucket_object.due_payments_validation_obj.name}"
 timeout               = 60
 entry_point           = "due_payments_validation"
 ingress_settings      = "ALLOW_ALL"
 service_account_email = "${var.sa_email}"
 runtime               = "python38"
 trigger_http          = true
}

##### EFFORT RATE NEW CREDIT VALIDATION #####

data "archive_file" "effort_rate_new_credit_validation_zip" {
  type        = "zip"
  source_dir  = "${path.module}/effort-rate-new-credit-validation"
  output_path = "${path.module}/files/effort_rate_new_credit_validation.zip"
}

# Storing zip to be used in the effort_rate_new_credit_validation cf
resource "google_storage_bucket_object" "effort_rate_new_credit_validation_obj" {
  name   = "cfs/effort_rate_new_credit_validation.zip"
  bucket = "${var.mds}"
  source = "${data.archive_file.effort_rate_new_credit_validation_zip.output_path}"
  depends_on = [data.archive_file.effort_rate_new_credit_validation_zip]
}

# effort_rate_new_credit_validation cf
resource "google_cloudfunctions_function" "effort_rate_new_credit_validation_cf" {
 name                  = "effort-rate-new-credit-validation"
 description           = "CF to validate effor rate in new credits"
 available_memory_mb   = 128
 source_archive_bucket = "${var.mds}"
 source_archive_object = "${google_storage_bucket_object.effort_rate_new_credit_validation_obj.name}"
 timeout               = 60
 entry_point           = "effort_rate_new_credit_validation"
 ingress_settings      = "ALLOW_ALL"
 service_account_email = "${var.sa_email}"
 runtime               = "python38"
 trigger_http          = true
}

##### EFFORT RATE TOTAL CREDIT VALIDATION #####

data "archive_file" "effort_rate_total_credit_validation_zip" {
  type        = "zip"
  source_dir  = "${path.module}/effort-rate-total-credit-validation"
  output_path = "${path.module}/files/effort_rate_total_credit_validation.zip"
}

# Storing zip to be used in the effort_rate_total_credit_validation cf
resource "google_storage_bucket_object" "effort_rate_total_credit_validation_obj" {
  name   = "cfs/effort_rate_total_credit_validation.zip"
  bucket = "${var.mds}"
  source = "${data.archive_file.effort_rate_total_credit_validation_zip.output_path}"
  depends_on = [data.archive_file.effort_rate_total_credit_validation_zip]
}

# effort_rate_total_credit_validation cf
resource "google_cloudfunctions_function" "effort_rate_total_credit_validation_cf" {
 name                  = "effort-rate-total-credit-validation"
 description           = "CF to validate total effor rate in credits"
 available_memory_mb   = 128
 source_archive_bucket = "${var.mds}"
 source_archive_object = "${google_storage_bucket_object.effort_rate_total_credit_validation_obj.name}"
 timeout               = 60
 entry_point           = "effort_rate_total_credit_validation"
 ingress_settings      = "ALLOW_ALL"
 service_account_email = "${var.sa_email}"
 runtime               = "python38"
 trigger_http          = true
}

##### JSON TO BASE64 #####

data "archive_file" "json_to_base64_zip" {
  type        = "zip"
  source_dir  = "${path.module}/json-to-base64"
  output_path = "${path.module}/files/json_to_base64.zip"
}

# Storing zip to be used in the json_to_base64 cf
resource "google_storage_bucket_object" "json_to_base64_obj" {
  name   = "cfs/json_to_base64.zip"
  bucket = "${var.mds}"
  source = "${data.archive_file.json_to_base64_zip.output_path}"
  depends_on = [data.archive_file.json_to_base64_zip]
}

# json_to_base64 cf
resource "google_cloudfunctions_function" "json_to_base64_cf" {
 name                  = "json-to-base64"
 description           = "CF convert json to base64"
 available_memory_mb   = 128
 source_archive_bucket = "${var.mds}"
 source_archive_object = "${google_storage_bucket_object.json_to_base64_obj.name}"
 timeout               = 60
 entry_point           = "json_to_base64"
 ingress_settings      = "ALLOW_ALL"
 service_account_email = "${var.sa_email}"
 runtime               = "python38"
 trigger_http          = true
}

##### SEND EMAIL #####

data "archive_file" "send_email_zip" {
  type        = "zip"
  source_dir  = "${path.module}/send-email"
  output_path = "${path.module}/files/send_email.zip"
}

# Storing zip to be used in the send_email cf
resource "google_storage_bucket_object" "send_email_obj" {
  name   = "cfs/send_email.zip"
  bucket = "${var.mds}"
  source = "${data.archive_file.send_email_zip.output_path}"
  depends_on = [data.archive_file.send_email_zip]
}

# send_email cf
resource "google_cloudfunctions_function" "send_email_cf" {
 name                  = "send-email"
 description           = "CF for sending notification mail"
 available_memory_mb   = 128
 source_archive_bucket = "${var.mds}"
 source_archive_object = "${google_storage_bucket_object.send_email_obj.name}"
 timeout               = 60
 entry_point           = "send_email"
 ingress_settings      = "ALLOW_ALL"
 service_account_email = "${var.sa_email}"
 runtime               = "python38"
 
 event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "${var.cf_sendmail_pubsub}"
    failure_policy {
      retry = false
    }
  }
}

##### STORAGE TO BQ #####

data "archive_file" "storageToBq_zip" {
  type        = "zip"
  source_dir  = "${path.module}/storage-to-bq"
  output_path = "${path.module}/files/storageToBq.zip"
}

# Storing zip to be used in the storageToBq cf
resource "google_storage_bucket_object" "storageToBq_obj" {
  name   = "cfs/storageToBq.zip"
  bucket = "${var.mds}"
  source = "${data.archive_file.storageToBq_zip.output_path}"
  depends_on = [data.archive_file.storageToBq_zip]
}

# storageToBq cf
resource "google_cloudfunctions_function" "storageToBq_cf" {
 name                  = "storage-to-bq"
 description           = "CF to push files from storage bucket to big query"
 available_memory_mb   = 128
 source_archive_bucket = "${var.mds}"
 source_archive_object = "${google_storage_bucket_object.storageToBq_obj.name}"
 timeout               = 60
 entry_point           = "storageToBq"
 ingress_settings      = "ALLOW_ALL"
 service_account_email = "${var.sa_email}"
 runtime               = "python38"

 event_trigger {
   event_type = "google.storage.object.finalize"
   resource   = "${var.main_bucket}"
   failure_policy {
     retry = false
   }
 }
}

##### TRIGGER WORKFLOW #####

data "archive_file" "trigger_workflow_zip" {
  type        = "zip"
  source_dir  = "${path.module}/trigger-workflow"
  output_path = "${path.module}/files/trigger_workflow.zip"
}

# Storing zip to be used in the trigger_workflow cf
resource "google_storage_bucket_object" "trigger_workflow_obj" {
  name   = "cfs/trigger_workflow.zip"
  bucket = "${var.mds}"
  source = "${data.archive_file.trigger_workflow_zip.output_path}"
  depends_on = [data.archive_file.trigger_workflow_zip]
}

# trigger_workflow cf
resource "google_cloudfunctions_function" "trigger_workflow_cf" {
 name                  = "trigger-workflow"
 description           = "CF for triggering workflow"
 available_memory_mb   = 128
 source_archive_bucket = "${var.mds}"
 source_archive_object = "${google_storage_bucket_object.trigger_workflow_obj.name}"
 timeout               = 60
 entry_point           = "trigger_workflow"
 ingress_settings      = "ALLOW_ALL"
 service_account_email = "${var.sa_email}"
 runtime               = "python38"
 
 event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "${var.cf_triggerworkflow_pubsub}"
    failure_policy {
      retry = false
    }
  }
}