resource "kubernetes_namespace_v1" "sausage_store" {
  metadata {
    name = "sausage-store"
  }
}


resource "helm_release" "sausage_store_app" {
  name       = "sausage-store-app"
  repository = "https://argoproj.github.io"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [
    yamlencode({
      "applications" = [{
        "name"      = "sausage-store"
        "namespace" = "argocd"
        "project"   = "default"
        "source" = {
          "repoURL"        = var.gitlab_git_url
          "path"           = "deploy-yandex-cloud" 
          "targetRevision" = "master"
          "helm" = {
            "valueFiles" = ["values.yaml"]
          }
        }
        "destination" = {
          "server"    = "https://kubernetes.default.svc"
          "namespace" = "sausage-store"
        }
        "syncPolicy" = {
          "automated" = { "prune" = true, "selfHeal" = true }
          "syncOptions" = ["CreateNamespace=true"]
        }
      }]
    })
  ]

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.sausage_repo_gitlab,
    kubernetes_secret_v1.gitlab_pull_secret,
    kubernetes_namespace_v1.sausage_store
  ]
}
