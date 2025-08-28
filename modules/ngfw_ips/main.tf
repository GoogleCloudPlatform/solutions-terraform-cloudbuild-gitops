resource "google_network_security_security_profile" "ips_security_profile" {
  name        = "ips-security-profile"
  parent      = "organizations/${var.org_id}"
  description = "default ips security profile"
  type        = "THREAT_PREVENTION"
}

resource "google_network_security_security_profile_group" "ips_security_profile_group" {
  name                      = "ips-security-profile-group"
  parent                    = "organizations/${var.org_id}"
  description               = "default ips security profile group"
  threat_prevention_profile = google_network_security_security_profile.ips_security_profile.id
}

resource "google_network_security_firewall_endpoint" "ips_endpoint" {
  name               = "ips-endpoint"
  parent             = "organizations/${var.org_id}"
  location           = "${var.subnetwork_region}-c"
  billing_project_id = var.project_id
}

resource "google_network_security_firewall_endpoint_association" "ips_endpoint_association" {
  name              = "ips-endpoint-association"
  parent             = "projects/${var.project_id}"
  network           = var.vpc_network
  location          = "${var.subnetwork_region}-c"
  firewall_endpoint = google_network_security_firewall_endpoint.ips_endpoint.id
}

resource "google_compute_network_firewall_policy" "ips_ngfw_policy" {
  name        = "ips-ngfw-policy"
  project     = var.project_id
  description = "Cloud NGFW for IPS"
}

resource "google_compute_network_firewall_policy_association" "ips_ngfw_policy_association" {
  name              = "ips-ngfw-policy-association"
  project           = var.project_id
  attachment_target = var.vpc_network
  firewall_policy   =  google_compute_network_firewall_policy.ips_ngfw_policy.id
}

resource "google_compute_network_firewall_policy_rule" "ips_l7_inspection_rule" {
  rule_name               = "ips-l7-inspection-rule"
  description             = "Send all incoming traffic for L7 inspection"
  firewall_policy         = google_compute_network_firewall_policy.ips_ngfw_policy.id
  
  disabled                = false
  enable_logging          = true
  
  priority                = 1000
  direction               = "INGRESS"
  
  match {
    src_ip_ranges = ["0.0.0.0/0"]
  
    layer4_configs {
      ip_protocol = "all"
    }
  }

  action                  = "apply_security_profile_group"
  security_profile_group  = google_network_security_security_profile_group.ips_security_profile_group.id
}

resource "google_compute_network_firewall_policy_rule" "allow_internal_http_icmp" {
  rule_name               = "allow-internal-http-icmp"
  description             = "allow http and icmp traffic from internal hosts"
  firewall_policy         = google_compute_network_firewall_policy.ips_ngfw_policy.id
  
  disabled                = false
  enable_logging          = true
  
  priority                = 2000
  direction               = "INGRESS"
  
  match {
    src_ip_ranges = [var.vpc_subnet_ip]
  
    layer4_configs {
      ip_protocol = "tcp"
      ports = [80]
    }
    layer4_configs {
      ip_protocol = "icmp"
    }
  }

  action                  = "allow"
}
