variable "enable_monium_key" {
  description = "Toggle for Monium configuration activation"  
  type    = bool
  default = false
}

resource "yandex_iam_service_account" "monium_sa" {
  count = var.enable_monium_key ? 1 : 0
  description = "Service account to send telemetry data to monium"
  name  = "monium-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "monium_sa_role" {
  # https://yandex.cloud/ru/docs/monium/security/#monium-telemetry-writer
  for_each  = var.enable_monium_key ? toset([
    "monium.telemetry.writer"
  ]) : []
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.monium_sa[0].id}"    
}

resource "yandex_iam_service_account_api_key" "monium_key" {
  count              = var.enable_monium_key ? 1 : 0
  service_account_id = yandex_iam_service_account.monium_sa[0].id
  scopes             = ["yc.monium.telemetry.write"]
}

resource "yandex_monitoring_notification_channel" "email_admin" {
  count     = var.enable_monium_key ? 1 : 0
  name      = "email-alerts-admin"
  folder_id = var.folder_id
  
  email {
    address_list = var.alert_email_addresses
  }
}

output "notification_channel_id" {
  value = one(yandex_monitoring_notification_channel.email_admin[*].id)
}

output "monium_api_key" {
  value     = one(yandex_iam_service_account_api_key.monium_key[*].secret_key)
  sensitive = true
}
