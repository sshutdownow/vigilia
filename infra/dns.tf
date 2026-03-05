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
    prevent_destroy = false

    # Игнорирует изменения в доменах, чтобы не инициировать перевыпуск
    ignore_changes = [domains]
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
data "yandex_cm_certificate" "vigilia-site" {
  depends_on      = [yandex_dns_recordset.validation_record]
  certificate_id  = yandex_cm_certificate.le_cert.id
  wait_validation = true
}

resource "yandex_dns_recordset" "observability_records" {
  for_each = toset(["grafana", "jaeger", "pyroscope", "k8s"])
  zone_id  = data.yandex_dns_zone.sausage_store_public_zone.id
  name     = "${each.value}.${var.domain_name}."
  type     = "A"
  ttl      = 900

  data = [yandex_kubernetes_cluster.k8s-cluster.master[0].external_v4_address]
}

# Отдельная запись для ArgoCD, привязанная к Gwin IP
resource "yandex_dns_recordset" "argocd_dns" {
  zone_id = data.yandex_dns_zone.sausage_store_public_zone.id
  name    = "argocd.${var.domain_name}."
  type    = "A"
  ttl     = 300
  data    = [data.kubernetes_resource.gw_status.object.status.addresses[0].value]
}

data "kubernetes_resource" "gw_status" {
  api_version = "gateway.networking.k8s.io/v1"
  kind        = "Gateway"
  metadata {
    name      = "argocd-gateway"
    namespace = "argocd"
  }
  depends_on = [helm_release.argocd]
}

resource "yandex_dns_recordset" "app_record" {
  zone_id = data.yandex_dns_zone.sausage_store_public_zone.id
  name    = "${var.domain_name}."
  type    = "A"
  ttl     = 900
  data    = [try(data.kubernetes_resource.gw_status.object.status.addresses[0].value, "127.0.0.1")]
  depends_on = [helm_release.gwin]
}