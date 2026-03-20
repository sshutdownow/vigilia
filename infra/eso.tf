resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "kube-system"
  create_namespace = true
  wait             = true

  depends_on = [yandex_kubernetes_cluster.k8s-cluster]
}
