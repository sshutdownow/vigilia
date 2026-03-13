resource "yandex_logging_group" "log_group_main" {
  # Если создать лог-группу с именем default,
  # она будет лог-группой по умолчанию для того каталога,
  # в котором создана
  name             = "default"
  folder_id        = var.folder_id
  retention_period = "36h"
}
