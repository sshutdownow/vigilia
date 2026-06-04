# Существующая публичная DNS-зона
data "yandex_dns_zone" "sausage_store_public_zone" {
  zone = "${var.domain_name}."
}

# Существующий сертификат Let's Encrypt
data "yandex_cm_certificate" "le_cert" {
  name = "sausage-store-le"
}

resource "yandex_dns_recordset" "k8s_dns_record" {
  for_each = toset(["k8s"])
  zone_id  = data.yandex_dns_zone.sausage_store_public_zone.id
  name     = "${each.value}.${var.domain_name}."
  type     = "A"
  ttl      = 900

  data = [yandex_kubernetes_cluster.k8s-cluster.master[0].external_v4_address]
}

# записи, привязанные к Gwin IP
resource "yandex_dns_recordset" "public_dns_records" {
  for_each = toset([
    "*.${var.domain_name}.",
    "${var.domain_name}."
  ])

  zone_id = data.yandex_dns_zone.sausage_store_public_zone.id
  name    = each.value
  type    = "A"
  ttl     = 300
  data    = [yandex_vpc_address.gwin_static_ip.external_ipv4_address[0].address]
}
