################################
## GCP Hub-spoke VPC構成の作成 ##
################################
# 1. VPCの作成
resource "google_compute_network" "hub_vpc" {
  provider = google


  name                            = "${var.gcp_project_hub}-hubvpc01"
  description                     = "This is a Hub VPC"
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  mtu                             = 1460
  delete_default_routes_on_create = true
}

resource "google_compute_network" "spoke_vpc" {
  provider = google.spoke

  name                            = "${var.gcp_project_spoke}-spokevpc01"
  description                     = "This is a Spoke VPC"
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  mtu                             = 1460
  delete_default_routes_on_create = true
}

# 2. Subnetの作成
resource "google_compute_subnetwork" "hub_vpc_subnet01" {
  provider = google

  name                     = "${var.gcp_project_hub}-hubvpc01-subnet01"
  description              = "This is a Subnet on Hub VPC"
  network                  = google_compute_network.hub_vpc.self_link
  ip_cidr_range            = "10.1.0.0/24"
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "spoke_vpc_subnet01" {
  provider = google.spoke

  name                     = "${var.gcp_project_spoke}-spokevpc01-subnet01"
  description              = "This is a Subnet on Spoke VPC"
  network                  = google_compute_network.spoke_vpc.self_link
  ip_cidr_range            = "10.2.0.0/24"
  private_ip_google_access = true
}

#3. Firewall Ruleの作成
resource "google_compute_firewall" "hub_firewall_ingress_ssh" {
  provider = google

  name      = "${var.gcp_project_hub}-hubvpc01-firewall01"
  network   = google_compute_network.hub_vpc.self_link
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22", "3389"] # SSHのみを許可
  }
  allow {
    protocol = "icmp" # ICMPを許可
  }
  source_ranges = ["10.11.0.0/24", "10.2.0.0/24"] # AWS VPC / Spoke VPCからの通信を許可
  target_tags   = ["local-traffic"]
}

resource "google_compute_firewall" "spoke_firewall" {
  provider = google.spoke

  name      = "${var.gcp_project_spoke}-spokevpc01-firewall01"
  network   = google_compute_network.spoke_vpc.self_link
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22", "3389"] # SSHのみを許可
  }
  allow {
    protocol = "icmp" # ICMPを許可
  }
  source_ranges = ["10.1.0.0/24"] # Hub VPCからの通信を許可
  target_tags   = ["local-traffic"]
}

# 4. （オプション）GCEインスタンスの作成
resource "google_compute_instance" "hub_vpc_instance01" {
  count    = var.is_create_gcp_instance
  provider = google

  name         = "${var.gcp_project_hub}-gce-instance01"
  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }
  tags = ["local-traffic"]
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = google_compute_subnetwork.hub_vpc_subnet01.self_link
    # External IPの設定。Private IPのみにする場合、以下は省略する
    #access_config {
    #}
  }
  scheduling {
    # 料金を抑えるためにプリエンプティブルにしておく
    preemptible = true
    # プリエンプティブルの場合は下のオプションが必須
    automatic_restart = false
  }
}

# Windows RDPテスト用サーバ
resource "google_compute_instance" "hub_vpc_win_instance01" {
  count    = var.is_create_gcp_instance
  provider = google

  name         = "${var.gcp_project_hub}-gce-win-instance01"
  machine_type = "e2-standard-2"
  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022"
    }
  }
  tags = ["local-traffic"]
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = google_compute_subnetwork.hub_vpc_subnet01.self_link
    # External IPの設定。Private IPのみにする場合、以下は省略する
    #access_config {
    #}
  }
  scheduling {
    # 料金を抑えるためにプリエンプティブルにしておく
    preemptible = true
    # プリエンプティブルの場合は下のオプションが必須
    automatic_restart = false
  }
}

resource "google_compute_instance" "spoke_vpc_instance01" {
  count    = var.is_create_gcp_instance
  provider = google.spoke

  name         = "${var.gcp_project_spoke}-gce-instance01"
  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }
  tags = ["local-traffic"]
  network_interface {
    network    = google_compute_network.spoke_vpc.self_link
    subnetwork = google_compute_subnetwork.spoke_vpc_subnet01.self_link
    # External IPの設定。Private IPのみにする場合、以下は省略する
    #access_config {
    #}
  }
  scheduling {
    # 料金を抑えるためにプリエンプティブルにしておく
    preemptible = true
    # プリエンプティブルの場合は下のオプションが必須
    automatic_restart = false
  }
}

# 5. VPC Peeringの作成
resource "google_compute_network_peering" "hub_vpc_peering_to_spoke" {
  provider = google

  name         = "${var.gcp_project_hub}-vpcpeering-to-${var.gcp_project_spoke}"
  network      = google_compute_network.hub_vpc.self_link
  peer_network = google_compute_network.spoke_vpc.self_link
}

resource "google_compute_network_peering" "spoke_vpc_peering_to_hub" {
  provider = google.spoke

  name         = "${var.gcp_project_spoke}-vpcpeering-to-${var.gcp_project_hub}"
  network      = google_compute_network.spoke_vpc.self_link
  peer_network = google_compute_network.hub_vpc.self_link
}

# 6. Routeの作成
/*
locals {
  hub_vpc_route_to_spoke_name = "${var.gcp_project_hub}-vpcpeering-to-${var.gcp_project_spoke}"
  spoke_vpc_route_to_hub_name = "${var.gcp_project_spoke}-vpcpeering-to-${var.gcp_project_hub}"
}

resource "google_compute_route" "hub_vpc_route_to_hub" {
  provider = google

  name               = "${local.hub_vpc_route_to_spoke_name}"
  network            = google_compute_network.hub_vpc.self_link
  dest_range         = google_compute_network.spoke_vpc.self_link
  next_hop_peering   = google_compute_network_peering.hub_spoke_peering.name
  priority           = 1000
}

resource "google_compute_route" "spoke_vpc_route_to_hub" {
  provider = google.spoke

  name               = "${local.spoke_vpc_route_to_hub_name}"
  network            = google_compute_network.spoke_vpc.self_link
  dest_range         = google_compute_network.hub_vpc.self_link
  next_hop_peering   = google_compute_network_peering.hub_spoke_peering.name
  priority           = 1000
}
*/

# 7. IPアドレスとPSC Endpointの作成
# 　 ※ 現時点のTerraform仕様だと、ServiceDirectoryのリージョン指定ができず、us-centralでの作成となる
resource "google_compute_global_address" "hub_vpc_private_ip_alloc" {
  provider = google

  name         = "${var.gcp_project_hub}siip01"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  address_type = "INTERNAL"
  network      = google_compute_network.hub_vpc.id
  address      = "100.100.111.111"
}

/*
resource "google_service_networking_connection" "hub_vpc_psc_endpoint" {
  network                 = google_compute_network.hub_vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.hub_vpc_private_ip_alloc.name]
}
*/

resource "google_compute_global_forwarding_rule" "forwarding_rule_private_service_connect" {
  provider = google

  name                  = replace("${var.gcp_project_hub}fwd01", "-", "")
  target                = "vpc-sc"
  network               = google_compute_network.hub_vpc.self_link
  ip_address            = google_compute_global_address.hub_vpc_private_ip_alloc.id
  load_balancing_scheme = ""
}

#######################
## GCP AWSとのVPN構成 ##
#######################

resource "google_compute_ha_vpn_gateway" "hub_vpc_havpn_gw" {
  count    = var.is_create_vpn_with_aws
  provider = google

  name    = "${var.gcp_project_hub}-havpn-gw01"
  network = google_compute_network.hub_vpc.self_link
}

resource "google_compute_router" "cmk_cloud_router" {
  count    = var.is_create_vpn_with_aws
  provider = google

  name    = "${var.gcp_project_hub}-router01"
  network = google_compute_network.hub_vpc.self_link
  bgp {
    asn = 65513
  }
}

resource "google_compute_external_vpn_gateway" "hub_vpc_extvpn_gw" {
  count    = var.is_create_vpn_with_aws
  provider = google

  name            = "${var.gcp_project_hub}-externalvpn-gw01"
  redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"
  description     = "Single IP for AWS VPN"

  interface {
    id         = 0
    ip_address = aws_vpn_connection.paloma-dv-vpc01-vpn01[0].tunnel1_address
  }
}

// VPNトンネル1の設定
// VPNトンネルの接続設定(トンネル1用)
resource "google_compute_vpn_tunnel" "hub_vpc_havpn_tunnel01" {
  count    = var.is_create_vpn_with_aws
  provider = google

  name                            = "${var.gcp_project_hub}-havpn-tunnel01"
  shared_secret                   = aws_vpn_connection.paloma-dv-vpc01-vpn01[0].tunnel1_preshared_key
  vpn_gateway                     = google_compute_ha_vpn_gateway.hub_vpc_havpn_gw[0].self_link
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.hub_vpc_extvpn_gw[0].self_link
  peer_external_gateway_interface = 0
  router                          = google_compute_router.cmk_cloud_router[0].name
  ike_version                     = 1
}
// Cloud Routerインターフェースの設定(トンネル1用)
resource "google_compute_router_interface" "hub_vpc_router_interface01" {
  count    = var.is_create_vpn_with_aws
  provider = google

  name       = "${var.gcp_project_hub}-router01-interface01"
  router     = google_compute_router.cmk_cloud_router[0].name
  ip_range   = "${aws_vpn_connection.paloma-dv-vpc01-vpn01[0].tunnel1_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.hub_vpc_havpn_tunnel01[0].name
}

// BGPピアリング用のBGP情報の設定(トンネル1用)
resource "google_compute_router_peer" "hub_vpc_router_peer01" {
  count    = var.is_create_vpn_with_aws
  provider = google

  name            = "${var.gcp_project_hub}-router01-peer01"
  router          = google_compute_router.cmk_cloud_router[0].name
  peer_ip_address = aws_vpn_connection.paloma-dv-vpc01-vpn01[0].tunnel1_vgw_inside_address
  peer_asn        = aws_vpn_connection.paloma-dv-vpc01-vpn01[0].tunnel1_bgp_asn
  interface       = google_compute_router_interface.hub_vpc_router_interface01[0].name
}
