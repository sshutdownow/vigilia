resource "yandex_resourcemanager_folder_iam_member" "k8s_roles" {
  for_each = toset([
    "k8s.clusters.agent",
    "monitoring.editor",
    "logging.writer",
    "ydb.editor",
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
    "container-registry.images.puller"#,
    # "lockbox.payloadViewer",
    # "kms.viewer",
    # "kms.keys.encrypterDecrypter"
  ])
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.k8s-node-group-sa.id}"
}
