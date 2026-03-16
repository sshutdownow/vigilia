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
resource "yandex_lockbox_secret_iam_binding" "sausage_backend_viewer" {
  secret_id = yandex_lockbox_secret.sausage_store_secrets.id
  role      = "lockbox.payloadViewer"
  members   = [
    "serviceAccount:${yandex_iam_service_account.sausage_backend_sa.id}"
  ]
}

# даём права SA нодам k8s-кластера использовать SA бэкенда (impersonation)
resource "yandex_iam_service_account_iam_binding" "node_sa_impersonate" {
  service_account_id = yandex_iam_service_account.sausage_backend_sa.id
  role               = "iam.serviceAccounts.user"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-node-group-sa.id}"
  ]
}
