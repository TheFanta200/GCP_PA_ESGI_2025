#!/bin/bash

# Configuration
DOMAIN="groupe-montel.fr"
SUBDOMAIN="novalys"
FULL_DOMAIN="novalys.groupe-montel.fr"
SERVICE_NAME="novalys-service"
NAMESPACE="default"

# Récupération dynamique de l'IP du LoadBalancer
echo "🔍 Récupération de l'IP du service LoadBalancer $SERVICE_NAME..."
IP_ADDRESS=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$IP_ADDRESS" ] || [ "$IP_ADDRESS" = "null" ]; then
    echo "❌ Erreur: Impossible de récupérer l'IP du service LoadBalancer $SERVICE_NAME"
    echo "💡 Vérifiez que le service existe et qu'il a une IP externe assignée:"
    echo "   kubectl get services -n $NAMESPACE"
    exit 1
fi

echo "✅ IP du LoadBalancer récupérée: $IP_ADDRESS"

# Variables Cloudflare (à configurer)
CF_API_TOKEN="VOTRE_CLEE_API"
CF_ZONE_ID=""  # Sera récupéré automatiquement si vide

# Fonction pour demander le token API de manière sécurisée
get_api_token() {
    if [ -z "$CF_API_TOKEN" ]; then
        echo "🔑 Configuration du token API Cloudflare"
        echo "💡 Vous pouvez obtenir un token API sur: https://dash.cloudflare.com/profile/api-tokens"
        echo "📋 Le token doit avoir les permissions 'Zone:Edit' pour le domaine groupe-montel.fr"
        echo ""
        read -s -p "🔐 Entrez votre token API Cloudflare: " CF_API_TOKEN
        echo ""
        
        if [ -z "$CF_API_TOKEN" ]; then
            echo "❌ Erreur: Token API requis pour continuer"
            exit 1
        fi
    fi
}

echo "🚀 Création de l'entrée DNS pour $FULL_DOMAIN -> $IP_ADDRESS"

# Fonction pour récupérer l'ID de la zone
get_zone_id() {
    if [ -z "$CF_ZONE_ID" ]; then
        echo "📡 Récupération de l'ID de la zone pour $DOMAIN..."
        CF_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json" | \
            jq -r '.result[0].id')
        
        if [ "$CF_ZONE_ID" = "null" ] || [ -z "$CF_ZONE_ID" ]; then
            echo "❌ Erreur: Impossible de trouver la zone pour $DOMAIN"
            exit 1
        fi
        echo "✅ Zone ID trouvé: $CF_ZONE_ID"
    fi
}

# Fonction pour vérifier si l'entrée DNS existe déjà
check_existing_record() {
    echo "🔍 Vérification de l'existence de l'enregistrement $FULL_DOMAIN..."
    EXISTING_RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$FULL_DOMAIN&type=A" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" | \
        jq -r '.result[0].id // empty')
    
    if [ -n "$EXISTING_RECORD" ]; then
        echo "⚠️  L'enregistrement existe déjà (ID: $EXISTING_RECORD)"
        return 0
    else
        echo "✅ Aucun enregistrement existant trouvé"
        return 1
    fi
}

# Fonction pour créer l'entrée DNS
create_dns_record() {
    echo "📝 Création de l'enregistrement DNS A pour $FULL_DOMAIN..."
    
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{
            "type": "A",
            "name": "novalys",
            "content": "'$IP_ADDRESS'",
            "ttl": 1,
            "proxied": true
        }')
    
    SUCCESS=$(echo $RESPONSE | jq -r '.success')
    
    if [ "$SUCCESS" = "true" ]; then
        RECORD_ID=$(echo $RESPONSE | jq -r '.result.id')
        echo "✅ Enregistrement DNS créé avec succès!"
        echo "   - Nom: $FULL_DOMAIN"
        echo "   - IP: $IP_ADDRESS"
        echo "   - ID: $RECORD_ID"
        echo "   - Proxied: ✅ Activé (Orange Cloud)"
        echo "   - TTL: Auto (géré par Cloudflare)"
    else
        echo "❌ Erreur lors de la création de l'enregistrement:"
        echo $RESPONSE | jq -r '.errors[].message'
        exit 1
    fi
}

# Fonction pour mettre à jour l'enregistrement DNS existant
update_dns_record() {
    echo "🔄 Mise à jour de l'enregistrement DNS existant..."
    
    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$EXISTING_RECORD" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{
            "type": "A",
            "name": "novalys",
            "content": "'$IP_ADDRESS'",
            "ttl": 1,
            "proxied": true
        }')
    
    SUCCESS=$(echo $RESPONSE | jq -r '.success')
    
    if [ "$SUCCESS" = "true" ]; then
        echo "✅ Enregistrement DNS mis à jour avec succès!"
        echo "   - Nom: $FULL_DOMAIN"
        echo "   - Nouvelle IP: $IP_ADDRESS"
        echo "   - Proxied: ✅ Activé (Orange Cloud)"
        echo "   - TTL: Auto (géré par Cloudflare)"
    else
        echo "❌ Erreur lors de la mise à jour de l'enregistrement:"
        echo $RESPONSE | jq -r '.errors[].message'
        exit 1
    fi
}

# Vérification des prérequis
get_api_token

if ! command -v jq &> /dev/null; then
    echo "❌ Erreur: jq n'est pas installé. Installation en cours..."
    sudo apt-get update && sudo apt-get install -y jq
fi

# Exécution principale
get_zone_id

if check_existing_record; then
    read -p "🤔 Voulez-vous mettre à jour l'enregistrement existant? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_dns_record
    else
        echo "⏭️  Opération annulée"
        exit 0
    fi
else
    create_dns_record
fi

echo ""
echo "🎉 Opération terminée! Votre site devrait être accessible à l'adresse:"
echo "   👉 http://$FULL_DOMAIN"
echo ""
echo "⏰ La propagation DNS peut prendre quelques minutes."
echo "🧪 Vous pouvez tester avec: dig $FULL_DOMAIN"