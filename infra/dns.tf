# Существующая публичная DNS-зона
data "yandex_dns_zone" "sausage_store_public_zone" {
  name = "vigilia-site"
}

# Существующий сертификат Let's Encrypt
data "yandex_cm_certificate" "le_cert" {
  name = "sausage-store-le"
}

resource "yandex_dns_recordset" "observability_records" {
  for_each = toset(["grafana", "jaeger", "pyroscope", "k8s"])
  zone_id  = data.yandex_dns_zone.sausage_store_public_zone.id
  name     = "${each.value}.${var.domain_name}."
  type     = "A"
  ttl      = 900

  data = [yandex_kubernetes_cluster.k8s-cluster.master[0].external_v4_address]
}

# запись для ArgoCD, привязанная к Gwin IP
resource "yandex_dns_recordset" "argocd_dns" {
  zone_id = data.yandex_dns_zone.sausage_store_public_zone.id
  name    = "argocd.${var.domain_name}."
  type    = "A"
  ttl     = 300
  data    = [yandex_vpc_address.gwin_static_ip.external_ipv4_address[0].address]
}

resource "yandex_dns_recordset" "app_record" {
  zone_id = data.yandex_dns_zone.sausage_store_public_zone.id
  name    = "${var.domain_name}."
  type    = "A"
  ttl     = 900
  data    = [yandex_vpc_address.gwin_static_ip.external_ipv4_address[0].address]
}