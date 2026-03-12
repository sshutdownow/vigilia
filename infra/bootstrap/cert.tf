# Существующая публичная DNS-зона
data "yandex_dns_zone" "sausage_store_public_zone" {
  name = "vigilia-site"
}

# Запрос на управляемый сертификат Let's Encrypt
resource "yandex_cm_certificate" "le_cert" {
  name      = "sausage-store-le"
  folder_id = var.folder_id
  domains   = [
    var.domain_name,
    "*.${var.domain_name}"
  ]

  managed {
    challenge_type = "DNS_CNAME" # Самый надежный способ для автоматизации
  }

  lifecycle {
    # Запрещает удаление сертификата через terraform destroy
    prevent_destroy = true

    # Игнорирует изменения в доменах, чтобы не инициировать перевыпуск
    ignore_changes = [domains, name]
  }
}

# Terraform берет данные из запроса сертификата и создает запись в DNS
resource "yandex_dns_recordset" "validation_record" {
  zone_id = data.yandex_dns_zone.sausage_store_public_zone.id
  name    = yandex_cm_certificate.le_cert.challenges[0].dns_name
  type    = yandex_cm_certificate.le_cert.challenges[0].dns_type
  data    = [yandex_cm_certificate.le_cert.challenges[0].dns_value]
  ttl     = 60
}

# АВТОМАТИЧЕСКАЯ ВАЛИДАЦИЯ
data "yandex_cm_certificate" "validated" {
  certificate_id  = yandex_cm_certificate.le_cert.id
  wait_validation = true
  depends_on      = [yandex_dns_recordset.validation_record]
}
