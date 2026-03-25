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

  cleanup_on_fail = true
  force_update    = true
  recreate_pods   = true
  wait            = true
  timeout         = 900

  depends_on = [yandex_kubernetes_node_group.k8s-node-group]  
}
