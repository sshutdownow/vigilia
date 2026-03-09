# Сервисный аккаунт для Gwin
resource "yandex_iam_service_account" "gwin_sa" {
  name = "gwin-sa"
  description = "service account for gwin"
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

resource "yandex_iam_service_account_key" "gwin_sa_key" {
  service_account_id = yandex_iam_service_account.gwin_sa.id
  description        = "Key for Gwin controller"
  key_algorithm      = "RSA_2048"
}

resource "helm_release" "gwin" {
  name             = "gwin"
  repository       = "oci://cr.yandex/yc-marketplace/yandex-cloud/gwin"
  version          = "v1.0.10"
  chart            = "gwin-chart"
  namespace        = "gwin-ns"
  create_namespace = true

  values = [<<-EOF
    controller:
      folderId: ${var.folder_id}
      ycServiceAccount:
        secret:
          value: |
            ${jsonencode({
              "id"                 : yandex_iam_service_account_key.gwin_sa_key.id,
              "service_account_id" : yandex_iam_service_account_key.gwin_sa_key.service_account_id,
              "created_at"         : yandex_iam_service_account_key.gwin_sa_key.created_at,
              "key_algorithm"      : yandex_iam_service_account_key.gwin_sa_key.key_algorithm,
              "public_key"         : yandex_iam_service_account_key.gwin_sa_key.public_key,
              "private_key"        : yandex_iam_service_account_key.gwin_sa_key.private_key
            })}
    gatewayClass:
      create: true
      name: yc-l7-gw
  EOF
  ]

  depends_on = [
    yandex_iam_service_account_key.gwin_sa_key,
    yandex_kubernetes_cluster.k8s-cluster
  ]
}
