# Variables
variable "project_id" {
  description = "ID du projet GCP"
  default     = "novalys-75000"
  type        = string
}

variable "region" {
  description = "Région GCP"
  default     = "europe-west9"
  type        = string
}

variable "zone" {
  description = "Zone GCP"
  default     = "europe-west9-b" 
  type        = string
}

###### Variables VPN #######
variable "vpn_region" {
  description = "Région pour le VPN"
  default     = "europe-west9"
  type        = string
}

variable "vpn_gateway_name" {
  description = "Nom de la passerelle VPN"
  default     = "vpn-gateway"
  type        = string
}

variable "vpn_tunnel_name" {
  description = "Nom du tunnel VPN"
  default     = "vpn-pontault-combault"
  type        = string
}

variable "vpn_peer_ip" {
  description = "Adresse IP du peer distant"
  default     = "82.66.171.71"
  type        = string
}

variable "vpn_ike_version" {
  description = "Version IKE pour le tunnel VPN"
  default     = 2
  type        = number
}

variable "vpn_local_traffic_selector" {
  description = "Plages de trafic local pour le tunnel VPN"
  default     = ["10.0.2.0/24"]
  type        = list(string)
}

variable "vpn_remote_traffic_selector" {
  description = "Plages de trafic distant pour le tunnel VPN"
  default     = [
    "192.168.10.0/24",
    "192.168.20.0/24",
    "192.168.30.0/24",
    "192.168.40.0/24",
    "192.168.50.0/24",
    "192.168.60.0/24",
    "192.168.70.0/24",
    "192.168.80.0/24",
    "192.168.90.0/24",
    "192.168.200.0/24"
  ]
  type        = list(string)
}

variable "vpn_route_priority" {
  description = "Priorité des routes VPN"
  default     = 1000
  type        = number
}