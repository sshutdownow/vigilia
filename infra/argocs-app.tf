resource "kubernetes_namespace_v1" "sausage_store" {
  metadata {
    name = "sausage-store"
  }
}

resource "time_sleep" "wait_infra" {
  depends_on = [
    yandex_kubernetes_cluster.k8s-cluster, 
    helm_release.gwin,
    helm_release.vpa,                      
    yandex_cm_certificate.le_cert
  ]

  create_duration = "120s" 
}

resource "null_resource" "infra" {
  depends_on = [
    time_sleep.wait_infra,
  ]
}

resource "kubernetes_manifest" "sausage_store_app" {
  manifest = {
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata" = {
      "name"      = "sausage-store"
      "namespace" = "argocd"
    }
    "spec" = {
      "project" = "default"
      "source" = {
        "repoURL"        = "${var.gitlab_git_url}"
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
        "automated" = {
          "prune"    = true
          "selfHeal" = true
        }
        "syncOptions" = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [
    resource.null_resource.infra,
    helm_release.argocd,
    kubernetes_secret_v1.sausage_repo_gitlab,
    kubernetes_secret_v1.gitlab_pull_secret,
    kubernetes_namespace_v1.sausage_store
  ]
}
