# Metrics Server, без него VPA не работает
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.13.0"
  namespace  = "kube-system"

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls}"
  }

  depends_on = [yandex_kubernetes_cluster.k8s-cluster]
}

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

  depends_on = [yandex_kubernetes_cluster.k8s-cluster, helm_release.metrics_server]
}
