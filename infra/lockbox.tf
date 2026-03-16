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

# права на чтение содержимого секрета (PayloadViewer)
resource "yandex_lockbox_secret_iam_binding" "viewer" {
  secret_id = yandex_lockbox_secret.sausage_store_secrets.id
  role      = "lockbox.payloadViewer"
  members   = ["serviceAccount:${yandex_iam_service_account.sausage_backend_sa.id}"]
}
