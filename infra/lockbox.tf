# Секрет в Lockbox, зашифрован KMS ключом
resource "yandex_lockbox_secret" "sausage_store_secrets" {
  name       = "sausage-store-kv"
  kms_key_id = yandex_kms_symmetric_key.kms-key.id
}

# сохраняем секреты в облако
resource "yandex_lockbox_secret_version" "v1" {
  secret_id = yandex_lockbox_secret.sausage_store_secrets.id
  
  entries {
    key        = "username"
    text_value = var.spring_datasource_user
  }
  entries {
    key        = "password"
    text_value = var.spring_datasource_pass
  }
  entries {
    key        = "mongo_uri"
    text_value = var.spring_mongo_uri
  }
}

# SA только для app backend
resource "yandex_iam_service_account" "sausage_backend_sa" {
  name = "sausage-backend-sa"
}

# даём права SA бэкенда на чтение секретов Lockbox
resource "yandex_resourcemanager_folder_iam_member" "sausage_backend_roles" {
  for_each  = toset([
    "lockbox.payloadViewer", # Чтобы видеть "обертку" секрета
    "kms.viewer"            # Чтобы расшифровать "начинку" ключом
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
