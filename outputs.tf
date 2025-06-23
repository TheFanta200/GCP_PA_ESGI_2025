# Outputs
output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "public_subnet_name" {
  value = google_compute_subnetwork.public_subnet.name
}

output "private_subnet_name" {
  value = google_compute_subnetwork.private_subnet.name
}

output "nat_gateway_name" {
  value = google_compute_router_nat.nat_gateway.name
}

output "nat_router_name" {
  value = google_compute_router.router.name
}
output "vpn_gateway_name" {
  value = google_compute_vpn_gateway.vpn_gateway.name
}

output "vpn_tunnel_name" {
  value = google_compute_vpn_tunnel.vpn_tunnel.name
}

output "vpn_static_ip" {
  value = google_compute_address.vpn_static_ip.address
}

output "vpn_routes" {
  value = [for route in google_compute_route.vpn_routes : route.name]
}