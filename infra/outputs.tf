output "k8s_external_v4_endpoint" {
  value = yandex_kubernetes_cluster.k8s-cluster.master[0].external_v4_endpoint
}

output "k8s_ca_certificate" {
  value = yandex_kubernetes_cluster.k8s-cluster.master[0].cluster_ca_certificate
}

output "k8s_cluster_id" {
  value = yandex_kubernetes_cluster.k8s-cluster.id
}

output "cert-id" {
  description = "Certificate ID"
  value       = yandex_cm_certificate.vigilia-site.id
}