
resource "yandex_iam_service_account" "eso_sa" {
  name = "external-secrets-sa"
  description = "Service account for ESO Yandex Lockbox"
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
  repository       = "https://charts.external-secrets.io"
#  repository       = "oci://cr.yandex/yc-marketplace/yandex-cloud/external-secrets/chart"
#  version          = "0.10.5"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  # https://yandex.cloud/ru/docs/managed-kubernetes/operations/applications/external-secrets-operator
  # https://external-secrets.io/latest/provider/yandex-lockbox/
  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
    # ,
    # { # Передаем ключ в формате JSON
    #   name  = "auth\\.json"
    #   value = jsonencode({
    #           "id"                 : yandex_iam_service_account_key.eso_sa_key.id,
    #           "service_account_id" : yandex_iam_service_account_key.eso_sa_key.service_account_id,
    #           "created_at"         : yandex_iam_service_account_key.eso_sa_key.created_at,
    #           "key_algorithm"      : yandex_iam_service_account_key.eso_sa_key.key_algorithm,
    #           "public_key"         : yandex_iam_service_account_key.eso_sa_key.public_key,
    #           "private_key"        : yandex_iam_service_account_key.eso_sa_key.private_key
    #   })
    # }
  ]

  cleanup_on_fail = true
  force_update    = true
  recreate_pods   = true
  wait            = true
  timeout         = 900

  depends_on = [yandex_kubernetes_node_group.k8s-node-group]
}

resource "kubernetes_secret_v1" "yc_auth" {
  metadata {
    name      = "yc-auth"
    namespace = "external-secrets"
  }

  data = {
    "auth" = jsonencode({
              "id"                 : yandex_iam_service_account_key.eso_sa_key.id,
              "service_account_id" : yandex_iam_service_account_key.eso_sa_key.service_account_id,
              "created_at"         : yandex_iam_service_account_key.eso_sa_key.created_at,
              "key_algorithm"      : yandex_iam_service_account_key.eso_sa_key.key_algorithm,
              "public_key"         : yandex_iam_service_account_key.eso_sa_key.public_key,
              "private_key"        : yandex_iam_service_account_key.eso_sa_key.private_key
      })
  }
  depends_on = [helm_release.external_secrets]
}
