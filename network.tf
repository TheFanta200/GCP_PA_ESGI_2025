# Configuration du réseau VPC et des sous-réseaux
# Création du VPC
resource "google_compute_network" "vpc" {
  name                    = "vpc-secure-network"
  auto_create_subnetworks = false
}

# Création du sous-réseau public
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Création du sous-réseau privé
resource "google_compute_subnetwork" "private_subnet" {
  name                     = "private-subnet"
  ip_cidr_range            = "10.0.2.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  # Blocs pour GKE
  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.10.0.0/16" # Plage pour les Pods
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.20.0.0/20" # Plage pour les Services
  }
}

# Création du routeur Cloud pour la NAT Gateway
resource "google_compute_router" "router" {
  name    = "nat-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# Configuration de la NAT Gateway
resource "google_compute_router_nat" "nat_gateway" {
  name                               = "nat-gateway"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}