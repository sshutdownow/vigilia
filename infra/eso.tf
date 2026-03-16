resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "kube-system"
  create_namespace = true
  wait             = true

  depends_on = [yandex_kubernetes_cluster.k8s-cluster]
}

# даём права SA бэкенда на чтение секретов Lockbox
resource "yandex_resourcemanager_folder_iam_member" "sausage_backend_roles" {
  for_each  = toset([
    "lockbox.payloadViewer", # Чтобы видеть "обертку" секрета
    "kms.viewer"             # Чтобы расшифровать "начинку" ключом
  ])
  
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.sausage_backend_sa.id}"
}

# даём права SA нодам k8s-кластера использовать SA бэкенда (impersonation)
resource "yandex_iam_service_account_iam_member" "node_sa_impersonate" {
  service_account_id = yandex_iam_service_account.sausage_backend_sa.id
  role               = "iam.serviceAccounts.user"
  member             = "serviceAccount:${yandex_iam_service_account.k8s-node-group-sa.id}"
}
