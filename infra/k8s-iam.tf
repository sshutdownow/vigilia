resource "yandex_iam_service_account" "k8s-sa" {
  description = "Service account to manage the Kubernetes cluster and node group"
  name        = var.sa_k8s
  folder_id   = var.folder_id
}

resource "yandex_iam_service_account" "k8s-node-group-sa" {
	description = "Service account to manage the Kubernetes node group"
  name        = var.sa_k8s_node_group
  folder_id   = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_roles" {
  for_each = toset([
    "k8s.clusters.agent",
    "monitoring.editor",
    "logging.writer",
    "storage.editor",
    "certificate-manager.certificates.downloader",
    "container-registry.images.puller",
    "container-registry.images.pusher",
    "alb.editor",
    "vpc.publicAdmin",
    "lockbox.payloadViewer",
    "kms.keys.encrypterDecrypter"
  ])
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_node_roles" {
  for_each = toset([
    "k8s.clusters.agent", 
    "container-registry.images.puller"
  ])
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.k8s-node-group-sa.id}"
}
