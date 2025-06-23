# Configuration de l'instance VM Rocky Linux dans le sous-réseau privé
# Variables pour la VM Rocky Linux
variable "rocky_vm_name" {
  description = "Nom de la VM Rocky Linux"
  default     = "rocky-linux-vm"
  type        = string
}

variable "rocky_vm_machine_type" {
  description = "Type de machine pour la VM Rocky Linux"
  default     = "e2-medium"  # Type de machine standard
  type        = string
}

variable "rocky_vm_boot_disk_size" {
  description = "Taille du disque de démarrage en GB pour la VM Rocky Linux"
  default     = 20
  type        = number
}

# Création de l'instance VM Rocky Linux
resource "google_compute_instance" "rocky_linux_vm" {
  name         = var.rocky_vm_name
  machine_type = var.rocky_vm_machine_type
  zone         = var.zone

  tags = ["private-vm"]

  boot_disk {
    initialize_params {
      image = "rocky-linux-cloud/rocky-linux-9"
      size  = var.rocky_vm_boot_disk_size
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    network_ip = "10.0.2.2"  # Force l'utilisation de l'IP spécifique
    # Pas d'adresse IP externe car la VM est dans un sous-réseau privé
  }

  # Configuration de SSH via OS Login
  metadata = {
    enable-oslogin = "TRUE"
  }

  # Ajouter un script de démarrage pour la configuration initiale
  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e  # Arrêter le script en cas d'erreur
    
    # Créer un fichier de log détaillé
    LOG_FILE="/var/log/startup-custom.log"
    exec > >(tee -a $LOG_FILE) 2>&1
    
    echo "=== Début du script de démarrage personnalisé ===" 
    echo "Date: $(date)"
    echo "Utilisateur: $(whoami)"
    echo "Permissions: $(id)"
    
    # Attendre que le réseau soit disponible
    echo "Attente de la connectivité réseau..."
    for i in {1..30}; do
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            echo "Réseau disponible après $i tentatives"
            break
        fi
        echo "Tentative $i/30: réseau non disponible, attente 10s..."
        sleep 10
    done
        
    # Installation des outils de base
    echo "Installation des outils de base..."
    dnf install -y wget curl vim git net-tools
    
    # Configuration du fuseau horaire
    echo "Configuration du fuseau horaire..."
    timedatectl set-timezone Europe/Paris
    
    # Vérifier la connectivité vers GitHub
    echo "Test de connectivité vers GitHub..."
    if ! curl -s --connect-timeout 10 https://github.com >/dev/null; then
        echo "ERREUR: Impossible de se connecter à GitHub"
        exit 1
    fi
    # Télécharger et vérifier le script avant exécution
    echo "Téléchargement du script personnalisé..."
    SCRIPT_URL="https://raw.githubusercontent.com/TheFanta200/google-gemini-clone/main/gcp-startup.sh"
    TEMP_SCRIPT="/tmp/gcp-startup.sh"
    # Utiliser curl pour télécharger le script avec des options de sécurité
    if curl -sSL --connect-timeout 30 --max-time 300 "$SCRIPT_URL" -o "$TEMP_SCRIPT"; then
        echo "Script téléchargé avec succès"
        echo "Taille du fichier: $(wc -c < $TEMP_SCRIPT) bytes"
        echo "Premiers caractères du script:"
        head -n 5 "$TEMP_SCRIPT"
        
        # Rendre le script exécutable
        chmod +x "$TEMP_SCRIPT"
        
        # Exécuter le script avec tous les privilèges
        echo "Exécution du script personnalisé avec sudo..."
        if sudo bash "$TEMP_SCRIPT"; then
            echo "✅ Script personnalisé exécuté avec succès!"
            echo "SUCCESS: Custom script completed" > /tmp/custom_script_status.log
        else
            echo "❌ Erreur lors de l'exécution du script personnalisé!"
            echo "FAILED: Custom script failed with exit code $?" > /tmp/custom_script_status.log
            exit 1
        fi
        
        # Nettoyer le fichier temporaire
        rm -f "$TEMP_SCRIPT"
    else
        echo "❌ Erreur lors du téléchargement du script!"
        echo "FAILED: Could not download script" > /tmp/custom_script_status.log
        exit 1
    fi
    
    echo "VM Rocky Linux configurée avec succès!" > /tmp/startup_success.log
    echo "=== Fin du script de démarrage personnalisé ==="
    echo "Configuration terminée le $(date)"
  EOF

  service_account {
    # Utiliser un compte de service par défaut avec un accès minimal
    scopes = ["cloud-platform"]
  }

  # Activer la configuration de la VM pour permettre l'accès via IAP
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}

# Sortie pour afficher l'adresse IP interne de la VM
output "rocky_vm_internal_ip" {
  value = google_compute_instance.rocky_linux_vm.network_interface[0].network_ip
  description = "Adresse IP interne de la VM Rocky Linux"
}