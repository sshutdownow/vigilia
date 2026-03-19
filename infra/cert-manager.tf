resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.4"
  namespace        = "cert-manager"
  create_namespace = true

  set =[{
    name  = "installCRDs"
    value = "true"
  }]
  
  cleanup_on_fail = true
  force_update    = true
  recreate_pods   = true
  wait            = true

  depends_on = [yandex_kubernetes_cluster.k8s-cluster]
}
