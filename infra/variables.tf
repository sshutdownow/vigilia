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

variable "k8s_version" {
  type        = string
  default     = "1.33"
  description = "Desired version of Kubernetes. See man page: https://cloud.yandex.com/en/docs/managed-kubernetes/concepts/release-channels-and-updates."
}

variable "sa_k8s" {
  type        = string
  default     = "k8s-cluster-argo"
  description = "Service account name for Kubernetes cluster. It must be unique in a cloud"
}

variable "sa_k8s_node_group" {
  type        = string
  default     = "k8s-node-group-argo"
  description = "Service account name for Kubernetes cluster. It must be unique in a cloud"
}

variable "container_registry_name" {
  type        = string
  default     = "diploma"
  description = "Container Registry name"
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
  default     = "infra-network"
}

variable "net_cidr" {
  description = "Subnet structure"
  type = list(object({
    name   = string,
    zone   = string,
    prefix = string
  }))

  default = [
    { name = "infra-subnet-a", zone = "ru-central1-a", prefix = "10.129.1.0/24" },
    { name = "infra-subnet-b", zone = "ru-central1-b", prefix = "10.130.1.0/24" },
    { name = "infra-subnet-d", zone = "ru-central1-d", prefix = "10.131.1.0/24" },
  ]
}

variable "domain_name" {
  type    = string
  default = "vigilia.site"
}

variable "argocd_admin_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "gitlab_username" {
  type      = string
  default   = null
  sensitive = true
}

variable "gitlab_token" {
  type      = string
  default   = null
  sensitive = true
}

variable "gitlab_git_url" {
  type    = string
  default = "https://cloud-services-engineer.gitlab.yandexcloud.net/s2633401/vigilia.git"
}

variable "gitlab_helm_url" {
  type    = string
  default = "cloud-services-engineer.gitlab.yandexcloud.net:5050/s2633401/vigilia/charts"
}

variable "gitlab_image_url" {
  type    = string
  default = "cloud-services-engineer.gitlab.yandexcloud.net:5050/s2633401/vigilia"
}

variable "vm_user" {
  description = "VM user"
  type        = string
  default     = "user"
}

variable "ssh_key" {
  description = "SSH Public Key"
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_private_key" {
  type        = string
  description = "SSH private key"
  sensitive   = true
  default     = null
}

variable "image_family" {
  type    = string
  default = "ubuntu-2404-lts-oslogin"
}

variable "platform_id" {
  type    = string
  default = "standard-v3"
}

variable "disk_type" {
  type    = string
  default = "network-hdd"
}

variable "disk_size" {
  type    = number
  default = 64 # min 30
}

variable "cores" {
  type    = string
  default = "2"
}

variable "memory" {
  type    = string
  default = "4"
}

variable "core_fraction" {
  type    = string
  default = "20"
}

variable "nat" {
  type    = bool
  default = false
}

variable "vm_preemptible" {
  type    = bool
  default = false
}
