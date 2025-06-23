# Création d'un null_resource pour déployer l'application via gcloud
resource "null_resource" "kubernetes_deployment" {
  # Cette ressource s'exécutera à chaque fois que le contenu du fichier manifeste change
  triggers = {
    manifest_sha1 = sha1(file("${path.module}/k8s/novalys.yaml"))
  }

  # Utilisation de la commande gcloud pour déployer l'application
  provisioner "local-exec" {
    command = <<EOT
      gcloud container clusters get-credentials ${google_container_cluster.private_gke.name} \
        --region ${var.region} \
        --project ${var.project_id} && \
      kubectl apply -f ${path.module}/k8s/novalys.yaml --validate=true && \
      echo "Vérification du déploiement des ressources..." && \
      kubectl get deployment novalys-deployment && \
      kubectl get hpa novalys-hpa
    EOT
  }

  depends_on = [
    google_container_cluster.private_gke
  ]
}