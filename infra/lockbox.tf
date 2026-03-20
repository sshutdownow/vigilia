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
