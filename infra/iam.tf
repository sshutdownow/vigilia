# Находим существующий SA по имени
data "yandex_iam_service_account" "k8s_sa" {
  name = var.sa_k8s
}

# Назначаем необходимые роли существующему SA
resource "yandex_resourcemanager_folder_iam_member" "k8s_roles" {
  for_each = toset([
    "k8s.clusters.agent", 
    "monitoring.editor", 
    "logging.writer", 
    "ydb.editor", 
    "storage.editor", 
    "lockbox.payloadViewer", 
    "certificate-manager.downloader", 
    "container-registry.images.puller",
    "alb.editor",
    "vpc.publicAdmin"
  ])
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${data.yandex_iam_service_account.k8s_sa.id}"
}
