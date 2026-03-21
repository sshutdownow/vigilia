variable "enable_monium_key" {
  description = "Флаг для активации генерации API-ключа Monium"  
  type    = bool
  default = false
}

resource "yandex_iam_service_account" "monium_sa" {
  count = var.enable_monium_key ? 1 : 0
  name  = "sausage-monium-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "monium_sa_role" {
  count     = var.enable_monium_key ? 1 : 0
  folder_id = var.folder_id
  role      = "monium.telemetry.writer"
  member    = "serviceAccount:${yandex_iam_service_account.monium_sa[0].id}"
}

resource "yandex_iam_service_account_api_key" "monium_key" {
  count              = var.enable_monium_key ? 1 : 0
  service_account_id = yandex_iam_service_account.monium_sa[0].id
  scopes             = ["yc.monium.telemetry.write"]
}

output "monium_api_key" {
  value     = one(yandex_iam_service_account_api_key.monium_key[*].secret_key)
  sensitive = true
}
