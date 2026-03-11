# Container Registry
resource "yandex_container_registry" "container-registry" {
  name      = local.registry_name
  folder_id = local.folder_id
}
