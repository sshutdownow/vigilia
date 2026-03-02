output "k8s_external_v4_endpoint" {
  value = value = yandex_kubernetes_cluster.my_cluster.master[0].external_v4_endpoint
}

output "k8s_ca_certificate" {
  value = yandex_kubernetes_cluster.my_cluster.master[0].cluster_ca_certificate
}

output "k8s_external_v4_address" {
  value = yandex_kubernetes_cluster.k8s-cluster.master[0].external_v4_address
}
