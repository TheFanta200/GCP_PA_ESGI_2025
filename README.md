# Infrastructure Novalys sur Google Cloud Platform

## 📋 Vue d'ensemble

Ce projet déploie une infrastructure complète sur Google Cloud Platform (GCP) pour héberger l'application **Novalys** avec les composants suivants :

- **🏗️ Infrastructure réseau sécurisée** avec VPC, sous-réseaux public/privé et NAT Gateway
- **🛡️ Règles de pare-feu** granulaires pour sécuriser les communications
- **☸️ Cluster GKE Autopilot** pour l'orchestration des conteneurs
- **🖥️ VM Rocky Linux** dans le sous-réseau privé pour des services complémentaires
- **🔐 Connexion VPN** pour l'accès sécurisé depuis le réseau local
- **🌐 Configuration DNS automatisée** avec Cloudflare
- **📊 Auto-scaling** et monitoring intégrés

## 🏗️ Architecture

```
                    ┌─────────────────────────────────────────┐
                    │           Réseau Local                  │
                    │          (82.66.171.71)                 │
                    │   192.168.10.0/24 - 192.168.200.0/24    │
                    └─────────────────┬───────────────────────┘
                                      │
                              ┌───────┴────────┐
                              │  Tunnel VPN    │
                              │    IPsec       │
                              └───────┬────────┘
                                      │
┌─────────────────────────────────────┼───────────────────────────────────┐
│                    FIREWALL RULES                                       │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ • allow-iap-ssh (SSH via IAP: 35.235.240.0/20 → port 22)            │ │
│ │ • allow-http (HTTP: 0.0.0.0/0 → port 80)                            │ │
│ │ • allow-gke-internal (GKE nodes communication)                      │ │
│ │ • allow-prometheus (Monitoring: 10.0.2.0/24 → 9090,9100,9093)       │ │
│ │ • allow-vpn-traffic (VPN networks → SSH, ICMP, port 5173)           │ │
│ │ • allow-egress-web (VM → Internet: HTTP/HTTPS/DNS)                  │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                         Google Cloud VPC                                │
│                       (vpc-secure-network)                              │
│                                                                         │
│  ┌─────────────────────┐  ┌──────────────────────────────────────────┐  │
│  │ Sous-réseau Public  │  │        Sous-réseau Privé                 │  │
│  │   10.0.1.0/24       │  │         10.0.2.0/24                      │  │
│  │                     │  │                                          │  │
│  │  ┌───────────────┐  │  │  ┌─────────────────────────────────────┐ │  │
│  │  │ VPN Gateway   │  │  │  │       VM Rocky Linux                │ │  │
│  │  │ (IPsec)       │◄─┼──┼─►│        10.0.2.2                     │ │  │
│  │  └───────────────┘  │  │  │    ┌─────────────────────────────┐  │ │  │
│  │                     │  │  │    │ Tags: private-vm            │  │ │  │
│  │                     │  │  │    │ Port 5173 (Dev Server)      │  │ │  │
│  │                     │  │  │    │ Internet via NAT            │  │ │  │
│  │                     │  │  │    └─────────────────────────────┘  │ │  │
│  │                     │  │  └─────────────────────────────────────┘ │  │
│  │                     │  │                                          │  │
│  │                     │  │  ┌─────────────────────────────────────┐ │  │
│  │                     │  │  │         Cluster GKE                 │ │  │
│  │                     │  │  │       (Novalys App)                 │ │  │
│  │                     │  │  │                                     │ │  │
│  │                     │  │  │ Tags: gke-node, gke-master          │ │  │
│  │                     │  │  │ Pods: 10.10.0.0/16                  │ │  │
│  │                     │  │  │ Services: 10.20.0.0/20              │ │  │
│  │                     │  │  │ Master: 172.16.0.32/28              │ │  │
│  │                     │  │  └─────────────────────────────────────┘ │  │
│  └─────────────────────┘  └──────────────────┬───────────────────────┘  │
│                                              │                          │
│  ┌───────────────────────────────────────────┴───────────────────────┐  │
│  │                      NAT Gateway                                  │  │
│  │                  (Accès Internet Sécurisé)                        │  │
│  └──────────────────────────────┬────────────────────────────────────┘  │
└─────────────────────────────────┼───────────────────────────────────────┘
                                  │
                        ┌─────────┴─────────┐
                        │   Load Balancer   │
                        │   (IP Publique)   │
                        │ Ports: 80/443     │
                        └─────────┬─────────┘
                                  │
                        ┌─────────┴─────────┐
                        │    Cloudflare     │
                        │  novalys.groupe-  │
                        │    montel.fr      │
                        └───────────────────┘
```

## 🚀 Prérequis

### Outils nécessaires
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [jq](https://stedolan.github.io/jq/) (pour le script DNS)

### Configuration GCP
1. **Créer un projet GCP** ou utiliser un existant
2. **Activer les APIs nécessaires** :
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable container.googleapis.com
   gcloud services enable dns.googleapis.com
   gcloud services enable servicenetworking.googleapis.com
   ```

3. **Configurer l'authentification** :
   ```bash
   gcloud auth login
   gcloud config set project novalys-75000
   ```

4. **Créer un compte de service** (optionnel mais recommandé) :
   ```bash
   gcloud iam service-accounts create terraform-sa \
     --display-name="Terraform Service Account"
   
   gcloud projects add-iam-policy-binding novalys-75000 \
     --member="serviceAccount:terraform-sa@novalys-75000.iam.gserviceaccount.com" \
     --role="roles/editor"
   
   gcloud iam service-accounts keys create terraform-key.json \
     --iam-account=terraform-sa@novalys-75000.iam.gserviceaccount.com
   
   export GOOGLE_APPLICATION_CREDENTIALS="./terraform-key.json"
   ```

## 📦 Déploiement

### 1. Cloner et configurer le projet

```bash
# Cloner le projet (ou télécharger les fichiers)
cd /home/esgi/GCP

# Vérifier la configuration
ls -la
```

### 2. Personnaliser les variables

Éditer le fichier `variables.tf` pour adapter à vos besoins :

```hcl
variable "project_id" {
  default = "votre-projet-gcp"  # ⚠️ À modifier
}

variable "vpn_peer_ip" {
  default = "votre-ip-publique"  # ⚠️ À modifier
}

variable "vpn_remote_traffic_selector" {
  default = ["192.168.x.0/24"]  # ⚠️ À adapter à vos réseaux
}
```

### 3. Initialiser Terraform

```bash
terraform init
```

### 4. Planifier le déploiement

```bash
terraform plan
```

### 5. Déployer l'infrastructure

```bash
terraform apply
```

⏱️ **Temps de déploiement estimé : 10-15 minutes**

### 6. Configurer kubectl

```bash
# Se connecter au cluster GKE
gcloud container clusters get-credentials private-gke-cluster \
  --region europe-west9 \
  --project novalys-75000
```

### 7. Déployer l'application Novalys

```bash
# Déployer l'application
kubectl apply -f k8s/novalys.yaml

# Vérifier le déploiement
kubectl get pods
kubectl get services
```

### 8. Configurer le DNS automatiquement

```bash
# Rendre le script exécutable
chmod +x create_dns_entry.sh

# Exécuter le script de configuration DNS
./create_dns_entry.sh
```

Le script va :
1. Récupérer automatiquement l'IP du LoadBalancer
2. Créer/mettre à jour l'enregistrement DNS sur Cloudflare
3. Configurer le domaine `novalys.groupe-montel.fr`

## 🔧 Configuration détaillée

### Composants réseau

| Composant | CIDR / Configuration |
|-----------|---------------------|
| VPC | `vpc-secure-network` |
| Sous-réseau public | `10.0.1.0/24` |
| Sous-réseau privé | `10.0.2.0/24` |
| Pods GKE | `10.10.0.0/16` |
| Services GKE | `10.20.0.0/20` |
| Master GKE | `172.16.0.32/28` |

### VM Rocky Linux

- **IP fixe** : `10.0.2.2`
- **Spécifications** : e2-standard-2 (2 vCPUs, 8 GB RAM)
- **Stockage** : 50 GB SSD
- **Accès** : SSH via IAP uniquement

### Cluster GKE

- **Mode** : Autopilot (géré automatiquement)
- **Zones** : `europe-west9-b`, `europe-west9-c`
- **Réseau** : Privé avec endpoint public
- **Auto-scaling** : 3-5 replicas selon la charge CPU

### Connexion VPN IPsec

- **Peer IP** : `82.66.171.71` (IP publique du site distant)
- **Protocole** : IPsec avec IKEv2
- **Réseaux locaux** : `10.0.2.0/24` (sous-réseau privé GCP)
- **Réseaux distants** : `192.168.10.0/24` à `192.168.90.0/24`
- **Tunnel** : `vpn-pontault-combault`
- **Gateway** : `vpn-gateway` dans la région `europe-west9`

### Règles de pare-feu (Firewall)

| Règle | Direction | Source | Destination | Ports | Description |
|-------|-----------|---------|-------------|-------|-------------|
| `allow-iap-ssh` | INGRESS | `35.235.240.0/20` | Toutes les VMs | `22` | SSH via Identity-Aware Proxy |
| `allow-http` | INGRESS | `0.0.0.0/0` | Tag: `private-vm` | `80` | HTTP vers VM privée |
| `allow-gke-internal` | INGRESS | Tag: `gke-node` | Tag: `gke-node` | `tcp/udp/icmp` | Communication interne GKE |
| `allow-prometheus` | INGRESS | `10.0.2.0/24` | Tag: `gke-node` | `9090,9100,9093` | Monitoring Prometheus |
| `allow-gke-ingress` | INGRESS | `0.0.0.0/0` | Tag: `gke-node` | `80,443,8080,8443` | Ingress Controllers |
| `allow-k8s-api` | INGRESS | `10.0.2.0/24` | Tag: `gke-master` | `443,6443` | API Kubernetes |
| `allow-debug` | INGRESS | `35.235.240.0/20` | Tag: `gke-node` | `22,3022,6443` | Débogage via IAP |
| `allow-lb-to-private` | INGRESS | `130.211.0.0/22,35.191.0.0/16` | Toutes les VMs | `80` | Load Balancer GCP |
| `allow-icmp-vpn` | INGRESS | Réseaux VPN | Toutes les VMs | `icmp` | Ping via VPN |
| `allow-ssh-vpn` | INGRESS | Réseaux VPN | Toutes les VMs | `22` | SSH via VPN |
| `allow-port-5173-to-rocky` | INGRESS | Réseaux VPN + `10.0.2.0/24` | `10.0.2.2/32` | `5173` | Dev server Rocky Linux |
| `allow-egress-web-rocky` | EGRESS | Tag: `private-vm` | `0.0.0.0/0` | `80,443,53` | Accès web depuis VM |
| `allow-private-subnet-egress` | EGRESS | `10.0.2.0/24` | `0.0.0.0/0` | `tcp/udp/icmp` | Trafic sortant via NAT |

### Ports et services

| Service | Port | Description |
|---------|------|-------------|
| SSH | 22 | Accès sécurisé via IAP |
| HTTP | 80 | Application web |
| HTTPS | 443 | Application web sécurisée |
| Novalys Dev | 5173 | Port de développement |
| Kubernetes API | 6443 | API du cluster |
| Prometheus | 9090, 9100, 9093 | Monitoring |

## 🛠️ Commandes utiles

### Terraform
```bash
# Voir l'état de l'infrastructure
terraform show

# Détruire l'infrastructure
terraform destroy

# Reformater les fichiers
terraform fmt

# Valider la configuration
terraform validate
```

### Kubernetes
```bash
# Voir les pods
kubectl get pods -o wide

# Voir les services
kubectl get services

# Voir les logs d'un pod
kubectl logs -f deployment/novalys-deployment

# Accéder à un pod
kubectl exec -it <pod-name> -- /bin/bash

# Mettre à jour l'image
kubectl set image deployment/novalys-deployment novalys=thefanta200/novalys:new-tag
```

### GCP
```bash
# Voir les instances
gcloud compute instances list

# Se connecter à la VM Rocky Linux via IAP
gcloud compute ssh rocky-linux-vm --zone=europe-west9-b --tunnel-through-iap

# Voir les règles de pare-feu
gcloud compute firewall-rules list

# Détails d'une règle de pare-feu
gcloud compute firewall-rules describe allow-iap-ssh

# Tester la connectivité réseau
gcloud compute networks list
gcloud compute routes list

# Voir les tunnels VPN
gcloud compute vpn-tunnels list --regions=europe-west9

# Statut de la NAT Gateway
gcloud compute routers get-status nat-router --region=europe-west9
```

## 🔍 Monitoring et debugging

### Vérifier l'état des services

```bash
# État du cluster
kubectl cluster-info

# État des nœuds
kubectl get nodes

# État des services
kubectl get svc

# Vérifier l'IP externe du LoadBalancer
kubectl get service novalys-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Logs et diagnostics

```bash
# Logs de l'application
kubectl logs -f -l app=novalys

# Événements du cluster
kubectl get events --sort-by=.metadata.creationTimestamp

# Décrire un pod problématique
kubectl describe pod <pod-name>
```

### Tests de connectivité

```bash
# Tester depuis la VM Rocky Linux
gcloud compute ssh rocky-linux-vm --zone=europe-west9-b --tunnel-through-iap --command="curl -I http://novalys.groupe-montel.fr"

# Tester la résolution DNS
dig novalys.groupe-montel.fr

# Tester l'accès direct à l'IP
curl -I http://<LOADBALANCER_IP>
```

## 🚨 Dépannage

### Problèmes courants

1. **Le LoadBalancer n'obtient pas d'IP externe**
   ```bash
   kubectl describe service novalys-service
   # Vérifier les quotas GCP et les règles de pare-feu
   ```

2. **Les pods ne démarrent pas**
   ```bash
   kubectl describe pod <pod-name>
   # Vérifier les ressources et les images
   ```

3. **Pas d'accès Internet depuis la VM**
   ```bash
   # Vérifier la NAT Gateway et les règles de pare-feu sortant
   gcloud compute routers list
   ```

4. **Problème de DNS**
   ```bash
   # Relancer le script DNS
   ./create_dns_entry.sh
   ```

5. **Problèmes de connectivité réseau/firewall**
   ```bash
   # Vérifier les règles de pare-feu actives
   gcloud compute firewall-rules list --filter="disabled=false"
   
   # Tester la connectivité depuis la VM Rocky Linux
   gcloud compute ssh rocky-linux-vm --zone=europe-west9-b --tunnel-through-iap \
     --command="curl -v google.com"
   
   # Vérifier les logs de pare-feu
   gcloud logging read 'resource.type="gce_subnetwork" AND logName="projects/novalys-75000/logs/compute.googleapis.com%2Ffirewall"' \
     --limit=50 --format=json
   
   # Tester l'accès VPN
   gcloud compute vpn-tunnels describe vpn-pontault-combault --region=europe-west9
   ```

6. **Problème d'accès au port 5173**
   ```bash
   # Vérifier que le service écoute sur la VM
   gcloud compute ssh rocky-linux-vm --zone=europe-west9-b --tunnel-through-iap \
     --command="sudo netstat -tlnp | grep 5173"
   
   # Tester depuis le réseau local (à exécuter depuis votre réseau local)
   curl -v http://10.0.2.2:5173
   ```

### Ressources utiles

- [Documentation GKE](https://cloud.google.com/kubernetes-engine/docs)
- [Documentation Terraform GCP](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloudflare API](https://developers.cloudflare.com/api/)

## 📝 Notes importantes

- ⚠️ **Sécurité** : Les règles de pare-feu sont configurées pour un environnement de développement/test
- 💰 **Coûts** : Surveillez les coûts GCP, notamment pour le cluster GKE et la NAT Gateway
- 🔄 **Sauvegarde** : Sauvegardez régulièrement votre configuration Terraform
- 🔐 **Secrets** : Ne commitez jamais vos tokens API ou clés privées

## 📞 Support

Pour toute question ou problème, consultez :
- Les logs GCP dans la console
- Les événements Kubernetes avec `kubectl get events`
- La documentation officielle des services utilisés

---

**Créé par** : ESGI DevOps Team  
**Dernière mise à jour** : juin 2025  
**Version** : 1.0
