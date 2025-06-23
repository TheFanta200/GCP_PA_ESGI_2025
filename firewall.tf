# Configuration des règles de pare-feu
# Règle de pare-feu pour autoriser SSH via IAP
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Plage d'adresses IP pour Identity-Aware Proxy
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["private-vm"]  # Ajout du tag pour cibler la VM Rocky Linux
  description   = "Permet les connexions SSH via IAP vers les VMs privées"
}

# Règle de pare-feu pour autoriser le trafic HTTP vers la VM privée
resource "google_compute_firewall" "allow_http_private" {
  name    = "allow-http-private-vm"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Limitation à des VMs spécifiques avec le tag "private-vm"
  target_tags = ["private-vm"]
  source_ranges = ["0.0.0.0/0"]
}

# Règle de pare-feu pour autoriser la communication interne du cluster GKE
resource "google_compute_firewall" "allow_gke_internal" {
  name    = "allow-gke-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  # Communication entre les nœuds GKE
  source_tags = ["gke-node"]
  target_tags = ["gke-node"]
  description = "Permet la communication entre les nœuds du cluster GKE"
}

# Règle de pare-feu pour autoriser l'accès aux metrics Prometheus
resource "google_compute_firewall" "allow_prometheus" {
  name    = "allow-prometheus"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["9090", "9100", "9093"] # Prometheus, node-exporter, Alertmanager
  }

  target_tags = ["gke-node"]
  source_ranges = ["10.0.2.0/24"] # Sous-réseau privé
  description = "Permet l'accès aux ports de monitoring"
}

# Règle de pare-feu pour autoriser l'Ingress GKE
resource "google_compute_firewall" "allow_gke_ingress" {
  name    = "allow-gke-ingress"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "8443"]
  }

  target_tags = ["gke-node"]
  source_ranges = ["0.0.0.0/0"]
  description = "Permet le trafic HTTP/HTTPS vers les ingress controllers de GKE"
}

# Règle de pare-feu pour autoriser l'accès au Kubernetes API Server
resource "google_compute_firewall" "allow_k8s_api" {
  name    = "allow-k8s-api"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443", "6443"] # Ports standard pour l'API Kubernetes
  }

  target_tags = ["gke-master"]
  source_ranges = ["10.0.2.0/24"] # Sous-réseau privé
  description = "Permet l'accès à l'API Kubernetes depuis le réseau privé"
}

# Règle de pare-feu pour autoriser les connexions de débogage
resource "google_compute_firewall" "allow_debug" {
  name    = "allow-debug"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3022", "6443"]
  }
  
  target_tags = ["gke-node"]
  source_ranges = ["35.235.240.0/20"] # Plage IAP pour une connexion sécurisée
  description = "Permet les connexions de débogage via IAP"
}

# Règle de pare-feu pour autoriser le trafic provenant des plages IP du Load Balancer
resource "google_compute_firewall" "allow_lb_to_private" {
  name    = "allow-lb-to-private"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"] # Plages IP des Load Balancers GCP
}

# Règle de pare-feu pour autoriser le ping (ICMP) à travers le VPN
resource "google_compute_firewall" "allow_icmp_vpn" {
  name    = "allow-icmp-vpn"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  # Source ranges correspondant aux plages d'adresses IP distantes du VPN
  source_ranges = var.vpn_remote_traffic_selector
  description = "Permet les pings à travers le VPN"
}

# Règle de pare-feu pour autoriser SSH à travers le VPN
resource "google_compute_firewall" "allow_ssh_vpn" {
  name    = "allow-ssh-vpn"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Source ranges correspondant aux plages d'adresses IP distantes du VPN
  source_ranges = var.vpn_remote_traffic_selector
  description = "Permet les connexions SSH à travers le VPN"
}

# Règle de pare-feu pour autoriser le port 3000 vers la VM Rocky Linux depuis le VPN
resource "google_compute_firewall" "allow_port_5173_to_rocky" {
  name    = "allow-port-3000-to-rocky"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  # Permet le trafic vers l'IP spécifique de la VM Rocky Linux
  destination_ranges = ["10.0.2.2/32"]
  # Autorise le trafic depuis les plages VPN et localement
  source_ranges = concat(var.vpn_remote_traffic_selector, ["10.0.2.0/24"])
  description = "Permet le trafic sur le port 3000 vers la VM Rocky Linux (10.0.2.2) depuis le VPN"
}

# Règle de pare-feu spécifique pour la console web GCP
resource "google_compute_firewall" "allow_gcp_console_ssh" {
  name    = "allow-gcp-console-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["private-vm"]
  # Plages IP utilisées par la console web GCP pour SSH
  source_ranges = [
    "35.235.240.0/20",  # IAP
    "199.36.153.8/30",  # Console GCP
    "199.36.153.4/30"   # Console GCP
  ]
  description = "Permet SSH depuis la console web GCP"
  priority = 500
}