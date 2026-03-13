resource "kubernetes_namespace_v1" "sausage_store" {
  metadata {
    name = "sausage-store"
  }
}

resource "helm_release" "sausage_store_app" {
  count      = 0
  name       = "sausage-store-app"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"
  version    = "2.0.4"
  
  values = [
    templatefile("${path.module}/argocd-app-values.yaml", {
      gitlab_helm_url  = var.gitlab_helm_url
      gitlab_image_url = var.gitlab_image_url
      certificate_id   = data.yandex_cm_certificate.le_cert.id
    })
  ]

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace_v1.sausage_store,
    kubernetes_secret_v1.sausage_repo_gitlab,
    kubernetes_secret_v1.sausage_helm_gitlab,
    kubernetes_secret_v1.gitlab_pull_secret
  ]
}
