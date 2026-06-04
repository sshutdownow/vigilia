# Создаём публичную DNS-зону
resource "yandex_dns_zone" "sausage_store_public_zone" {
  name   = trim(replace(lower(var.domain_name), "/[^a-z0-9]+/", "-"), "-")
  zone   = "${var.domain_name}." # точка обязательна
  public = true
}
