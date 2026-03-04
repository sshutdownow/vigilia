# Регистрация реестра как OCI-репозитория
resource "kubernetes_manifest" "yc_registry_oci" {
  manifest = {
    apiVersion = "v1", kind = "Secret"
    metadata = { 
      name      = "yc-registry-oci"
      namespace = "argocd"
      labels    = { "argocd.argoproj.io/secret-type" = "repository" }
    }
    string_data = {
      type      = "helm"
      name      = "yc-oci"
      enableOCI = "true"
      # Используем ID твоего существующего реестра
      url       = "cr.yandex/${yandex_container_registry.container-registry.id}"
      username  = "json_key"
      password  = file("authorized_key.json")
    }
  }
}

# Application: деплой Sausage Store из OCI чарта
resource "kubernetes_manifest" "sausage_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1", kind = "Application"
    metadata = { name = "sausage-store", namespace = "argocd" }
    spec = {
      project = "default"
      source = {
        repoURL        = "cr.yandex/${yandex_container_registry.container-registry.id}"
        chart          = "sausage-store"
        targetRevision = "1.0.0" # Версия чарта, которую запушит пайплайн
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
      destination = { server = "https://kubernetes.default.svc", namespace = "sausage-store" }
      syncPolicy = { automated = { prune = true, selfHeal = true }, syncOptions = ["CreateNamespace=true"] }
    }
  }
  depends_on = [kubernetes_manifest.yc_registry_oci]
}
