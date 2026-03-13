resource "kubernetes_namespace_v1" "sausage_store" {
  metadata {
    name = "sausage-store"
  }
}

resource "helm_release" "sausage_store_app" {
  count = 1
  name       = "sausage-store-app"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [
    yamlencode({
      applications = [{
        name      = "sausage-store"
        namespace = "argocd"
        project   = "default"
        source = {
          # Репозиторий чарта (OCI)
          repoURL        = "oci://${var.gitlab_helm_url}"
          path           = "sausage-store"
          chart          = "sausage-store"
          targetRevision = "1.0.161" # Версия чарта из CI
          
          helm = {
            values = yamlencode({
              global = {
                # Секрет для скачивания образов нодами
                imagePullSecrets = [{ name = "gitlab-pull-secret" }]
              }

              backend = {
                image = "${var.gitlab_image_url}/sausage-backend"
              }
              frontend = {
                image = "${var.gitlab_image_url}/sausage-frontend"
              }
              backend-report = {
                image = "${var.gitlab_image_url}/sausage-backend-report"
              }

              ingress = {
                annotations = {
                  "gwin.yandex.cloud/certificateId" = data.yandex_cm_certificate.le_cert.id
                }
              }
            })
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "sausage-store"
        }
        syncPolicy = {
          automated   = { prune = true, selfHeal = true }
          syncOptions = ["CreateNamespace=true"]
        }
      }]
    })
  ]

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.sausage_repo_gitlab,
    kubernetes_secret_v1.sausage_helm_gitlab,
    kubernetes_secret_v1.gitlab_pull_secret
  ]
}
