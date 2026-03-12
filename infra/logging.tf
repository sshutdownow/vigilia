resource "yandex_logging_group" "log_group_main" {
  name             = "main-log-group"
  folder_id        = var.folder_id
  retention_period = "36h"
}
