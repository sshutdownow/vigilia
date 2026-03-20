
resource "yandex_iam_service_account" "eso_sa" {
  name = "external-secrets-sa"
}

resource "yandex_iam_service_account_key" "eso_sa_key" {
  service_account_id = yandex_iam_service_account.eso_sa.id
  description        = "Key for External Secrets Operator"
  key_algorithm      = "RSA_2048"
}

resource "yandex_resourcemanager_folder_iam_member" "eso_sa_roles" {
  for_each  = toset([
    "lockbox.payloadViewer",
    "kms.viewer",
    "kms.keys.encrypterDecrypter"
  ])

  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.eso_sa.id}"
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "oci://cr.yandex/yc-marketplace/yandex-cloud/external-secrets/chart"
  version          = "0.10.5"
#  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true

  # https://yandex.cloud/ru/docs/managed-kubernetes/operations/applications/external-secrets-operator
  # https://external-secrets.io/latest/provider/yandex-lockbox/
  # Передаем ключ в формате JSON
  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "auth.json"
      value = jsonencode({
        service_account_id = yandex_iam_service_account_key.eso_sa_key.service_account_id
        key_id             = yandex_iam_service_account_key.eso_sa_key.id
        public_key         = yandex_iam_service_account_key.eso_sa_key.public_key
        private_key        = yandex_iam_service_account_key.eso_sa_key.private_key
      })
    }
  ]

  depends_on = [yandex_kubernetes_cluster.k8s-cluster]
}
