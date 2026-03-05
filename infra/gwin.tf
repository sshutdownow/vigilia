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
