resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  set = [
    {
      name  = "configs.params.server\\.insecure"
      value = "true"
    },
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = var.argocd_admin_password
    },
    { # GWIN
      name  = "server.service.type"
      value = "NodePort"
    }
  ]
}

resource "kubernetes_secret_v1" "yc_registry_oci" {
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
    # Reference your existing registry resource
    url      = "cr.yandex/${yandex_container_registry.container-registry.id}"
    username = "json_key"
    password = file("authorized_key.json")
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret_v1" "sausage_repo_gitlab" {
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

# Gateway (балансировщик с SSL сертификатом)
resource "kubernetes_manifest" "argocd_gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "argocd-gateway"
      namespace = "argocd"
      annotations = {
        "gateway.yc.io/certificate-id" = yandex_cm_certificate.le_cert.id
      }
    }
    spec = {
      gatewayClassName = "yc-l7-gw"
      listeners = [{
        name          = "https"
        protocol      = "HTTPS"
        port          = 443
        allowedRoutes = { namespaces = { from = "Same" } }
      }]
    }
  }
  depends_on = [kubernetes_manifest.gateway_class, data.yandex_cm_certificate.vigilia-site]
}

# HTTPRoute для маршрутизации домена
resource "kubernetes_manifest" "argocd_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "argocd-route"
      namespace = "argocd"
    }
    spec = {
      parentRefs = [{ name = "argocd-gateway" }]
      hostnames  = ["argocd.vigilia.site"]
      rules = [{
        backendRefs = [{
          name = "argocd-server"
          port = 80
        }]
      }]
    }
  }
  depends_on = [kubernetes_manifest.argocd_gateway]
}