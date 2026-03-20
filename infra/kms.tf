resource "yandex_kms_symmetric_key" "kms-key" {
  # Ключ Yandex Key Management Service для шифрования важной информации,
  # такой как пароли, OAuth-токены и SSH-ключи.
  name              = "kms-key"
  default_algorithm = "AES_128"
  rotation_period   = "8760h" # 1 год.
  folder_id         = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "encrypterDecrypter" {
  symmetric_key_id = yandex_kms_symmetric_key.kms-key.id
  role             = "kms.keys.encrypterDecrypter"

  members = [
    "serviceAccount:${yandex_iam_service_account.sausage_backend_sa.id}",
  ]
}
