# Существующая публичная DNS-зона
data "yandex_dns_zone" "sausage_store_public_zone" {
  name = "vigilia-site"
}

# Запрос на управляемый сертификат Let's Encrypt
resource "yandex_cm_certificate" "le_cert" {
  name      = "sausage-store-le"
  folder_id = var.folder_id
  domains   = [var.domain_name, "*.${var.domain_name}"]
  managed {
    challenge_type = "DNS_CNAME" # Самый надежный способ для автоматизации
  }
  lifecycle {
    # Запрещает удаление сертификата через terraform destroy
    prevent_destroy = true

    # Игнорирует изменения в доменах, чтобы не инициировать перевыпуск
    ignore_changes = [domains]
  }
}

# АВТОМАТИЧЕСКАЯ ВАЛИДАЦИЯ
# Terraform берет данные из запроса сертификата и создает запись в DNS
resource "yandex_dns_recordset" "validation_record" {
  zone_id = data.yandex_dns_zone.sausage_store_public_zone.id
  name    = yandex_cm_certificate.le_cert.challenges[0].dns_name
  type    = yandex_cm_certificate.le_cert.challenges[0].dns_type
  data    = [yandex_cm_certificate.le_cert.challenges[0].dns_value]
  ttl     = 60
}

resource "yandex_dns_recordset" "observability_records" {
  for_each = toset(["grafana", "jaeger", "pyroscope", "argocd", "k8s"])
  zone_id  = data.yandex_dns_zone.sausage_store_public_zone.id
  name     = "${each.value}.${var.domain_name}."
  type     = "A"
  ttl      = 600

  data = [yandex_kubernetes_cluster.k8s-cluster.master[0].external_v4_address]
}
