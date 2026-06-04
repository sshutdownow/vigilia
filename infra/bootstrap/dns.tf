# Создаём публичную DNS-зону
resource "yandex_dns_zone" "sausage_store_public_zone" {
  name   = replace(${var.domain_name}, ".", "-")
  zone   = "${var.domain_name}." # точка обязательна
  public = true
}
