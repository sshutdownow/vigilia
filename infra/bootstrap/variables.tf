# ===============
# Variables
# ===============

variable "cloud_id" {
  description = "Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Folder ID"
  type        = string
}

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "domain_name" {
  type    = string
  default = "vigilia.site"
}
