output "k8s_external_v4_endpoint" {
  value = yandex_kubernetes_cluster.k8s-cluster.master[0].external_v4_endpoint
}

output "k8s_ca_certificate" {
  value = yandex_kubernetes_cluster.k8s-cluster.master[0].cluster_ca_certificate
  sensitive = true
}

output "k8s_cluster_id" {
  value = yandex_kubernetes_cluster.k8s-cluster.id
}

output "cert-id" {
  description = "LE certificate ID"
  value       = data.yandex_cm_certificate.le_cert.id
}

output "argocd_domain" {
  description = "ArgoCD Web"
  value = "argocd.${var.domain_name}"
}
