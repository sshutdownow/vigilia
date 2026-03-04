# 1. Установка ArgoCD через Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  wait             = true

  set = [
    {
      name  = "configs.params.server\\.insecure"
      value = "true"
    },
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = var.argocd_admin_password
    }
  ]

  depends_on = [yandex_kubernetes_cluster.k8s-cluster]
}

resource "kubernetes_secret" "yc_registry_oci" {
  metadata {
    name      = "yc-registry-oci"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type      = "helm"
    name      = "yc-oci"
    enableOCI = "true"
    url       = "cr.yandex/${yandex_container_registry.container-registry.id}"
    username  = "json_key"
    password  = file("authorized_key.json")
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret" "sausage_repo_gitlab" {
  metadata {
    name      = "sausage-repo-gitlab"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type     = "git"
    url      = "https://cloud-services-engineer.gitlab.yandexcloud.net"
    password = var.gitlab_access_token
    username = "gitops-bot"
  }

  depends_on = [helm_release.argocd]
}


# 4. Root Application: Деплой Sausage Store из OCI-чарта
resource "kubernetes_manifest" "sausage_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "sausage-store"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        # Тянем чарт из Container Registry (OCI)
        repoURL        = "cr.yandex/${yandex_container_registry.container-registry.id}"
        chart          = "sausage-store"
        targetRevision = "1.0.0"
        helm = {
          values = yamlencode({
            ingress = {
              annotations = {
                "gwin.ingress.kubernetes.io/certificate-id" = yandex_cm_certificate.le_cert.id
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
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [kubernetes_manifest.yc_registry_oci]
}
