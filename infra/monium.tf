variable "enable_monium_key" {
  description = "Флаг для активации генерации API-ключа Monium"  
  type    = bool
  default = false
}

resource "yandex_iam_service_account" "monium_sa" {
  count = var.enable_monium_key ? 1 : 0
  name  = "sausage-monium-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "monitoring_editor" {
  count     = var.enable_monium_key ? 1 : 0
  folder_id = var.folder_id
  role      = "monitoring.editor"
  member    = "serviceAccount:${yandex_iam_service_account.monium_sa[0].id}"
}

resource "yandex_iam_service_account_api_key" "monium_key" {
  count              = var.enable_monium_key ? 1 : 0
  service_account_id = yandex_iam_service_account.monium_sa[0].id
}

output "monium_api_key" {
  value     = length(yandex_iam_service_account_api_key.monium_key) > 0 ? yandex_iam_service_account_api_key.monium_key[0].secret_key : ""
  sensitive = true
}
