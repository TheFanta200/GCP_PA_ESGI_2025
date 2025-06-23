# Configuration VPN
# Création de la passerelle VPN cible
resource "google_compute_address" "vpn_static_ip" {
  name   = "${var.vpn_gateway_name}-ip"
  region = var.vpn_region
}

# Création de la passerelle VPN
resource "google_compute_vpn_gateway" "vpn_gateway" {
  name        = var.vpn_gateway_name
  description = "VPN Réseau privé"
  network     = google_compute_network.vpc.id
  region      = var.vpn_region
}

# Règles de transfert pour la passerelle VPN
resource "google_compute_forwarding_rule" "vpn_rule_esp" {
  name        = "${var.vpn_gateway_name}-rule-esp"
  region      = var.vpn_region
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_static_ip.address
  target      = google_compute_vpn_gateway.vpn_gateway.id
}

resource "google_compute_forwarding_rule" "vpn_rule_udp500" {
  name        = "${var.vpn_gateway_name}-rule-udp500"
  region      = var.vpn_region
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_address.vpn_static_ip.address
  target      = google_compute_vpn_gateway.vpn_gateway.id
}

resource "google_compute_forwarding_rule" "vpn_rule_udp4500" {
  name        = "${var.vpn_gateway_name}-rule-udp4500"
  region      = var.vpn_region
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_address.vpn_static_ip.address
  target      = google_compute_vpn_gateway.vpn_gateway.id
}

# Accès au secret de la clé partagée VPN depuis Secret Manager
data "google_secret_manager_secret_version" "vpn_shared_secret" {
  secret  = "vpn-shared-secret"
  version = "latest"
  project = var.project_id
}

# Création du tunnel VPN avec la clé partagée depuis Secret Manager
resource "google_compute_vpn_tunnel" "vpn_tunnel" {
  name                   = var.vpn_tunnel_name
  region                 = var.vpn_region
  peer_ip                = var.vpn_peer_ip
  shared_secret          = data.google_secret_manager_secret_version.vpn_shared_secret.secret_data
  ike_version            = var.vpn_ike_version
  local_traffic_selector = var.vpn_local_traffic_selector
  remote_traffic_selector = var.vpn_remote_traffic_selector
  target_vpn_gateway     = google_compute_vpn_gateway.vpn_gateway.id
  
  depends_on = [
    google_compute_forwarding_rule.vpn_rule_esp,
    google_compute_forwarding_rule.vpn_rule_udp500,
    google_compute_forwarding_rule.vpn_rule_udp4500
  ]
}


# Création dynamique des routes pour le tunnel VPN
resource "google_compute_route" "vpn_routes" {
  count               = length(var.vpn_remote_traffic_selector)
  name                = "${var.vpn_tunnel_name}-route-${(count.index + 1) * 10}"
  network             = google_compute_network.vpc.name
  priority            = var.vpn_route_priority
  dest_range          = var.vpn_remote_traffic_selector[count.index]
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.vpn_tunnel.self_link
}