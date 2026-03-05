# Сервисный аккаунт для Gwin
resource "yandex_iam_service_account" "gwin_sa" {
  name = "gwin-sa"
}

# Назначение ролей
resource "yandex_resourcemanager_folder_iam_member" "gwin_roles" {
  for_each = toset([
    "alb.editor",
    "certificate-manager.certificates.downloader",
    "compute.viewer",
    "vpc.publicAdmin",
    "k8s.viewer"
  ])
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.gwin_sa.id}"
}

resource "helm_release" "gwin" {
  name             = "gwin"
  repository       = "oci://cr.yandex/yc-marketplace/yandex-cloud/gwin"
  version          = "v1.0.10"
  chart            = "gwin-chart"
  namespace        = "gwin-ns"
  create_namespace = true

  set = [
    { name = "serviceAccount.id", value = yandex_iam_service_account.gwin_sa.id },
    { name = "controller.folderId", value = var.folder_id },
    { name = "gatewayClass.create", value = "true" },
    { name = "gatewayClass.name",   value = "yc-l7-gw" }
  ]
  depends_on = [yandex_resourcemanager_folder_iam_member.gwin_roles]
}

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
      listeners = [
        { name = "https", protocol = "HTTPS", port = 443, allowedRoutes = { namespaces = { from = "Same" } } },
        { name = "http",  protocol = "HTTP",  port = 80,  allowedRoutes = { namespaces = { from = "Same" } } }
      ]
    }
  }
  depends_on = [helm_release.gwin, data.yandex_cm_certificate.vigilia-site]
}

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
      hostnames  = ["argocd.${var.domain_name}"]
      rules = [{
        matches = [{ path = { type = "PathPrefix", value = "/" } }]
        backendRefs = [{ name = "argocd-server", port = 80 }]
      }]
    }
  }
  depends_on = [kubernetes_manifest.argocd_gateway]
}
