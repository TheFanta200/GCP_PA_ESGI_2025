# Configuration du cluster GKE
resource "google_container_cluster" "private_gke" {
  name       = "private-gke-cluster"
  location   = var.region
  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.private_subnet.name

  # Spécifier des zones spécifiques, si nécessaire
  node_locations = ["europe-west9-b", "europe-west9-c"]

  # Configuration IP
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # Configuration privée - Modification pour permettre l'accès public à l'API
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false 
    master_ipv4_cidr_block  = "172.16.0.32/28"
  }

  # Autorisation d'accès à l'API - Ajouter votre adresse IP publique
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "192.168.0.0/16"
      display_name = "reserved-network-access"
    }
    cidr_blocks {
      cidr_block   = "82.66.171.71/32"
      display_name = "public-access"
    }
  }

  # Configuration de logging et monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
  
  # Activer le mode Autopilot
  enable_autopilot = true
  deletion_protection = false
}