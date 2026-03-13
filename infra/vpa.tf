# VPA Controller
resource "helm_release" "vpa" {
  name       = "vpa"
  repository = "https://charts.fairwinds.com/stable"
  chart      = "vpa"
  version    = "4.7.2"
  namespace  = "vpa"

  create_namespace = true

  values = [
    yamlencode({
      recommender = {
        enabled = true
      }
      updater = {
        enabled = true
      }
      admissionController = {
        enabled = true
      }
    })
  ]

  depends_on = [yandex_kubernetes_cluster.k8s-cluster]
}
