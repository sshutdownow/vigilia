# ==================================
# Terraform & Provider Configuration
# ==================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.130"
    }
    helm = {
      source = "hashicorp/helm"
      version = ">= 3.1.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 3.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }
    bcrypt = {
      source = "viktorradnai/bcrypt"
      version = ">= 0.1.2"
    }
  }

  backend "http" {
  }
}

provider "yandex" {
  service_account_key_file = "authorized_key.json"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

# Используем временный токен, который Terraform может получить из контекста авторизации самого провайдера Yandex
data "yandex_client_config" "client" {}

provider "helm" {
  debug = true
  kubernetes = {
    host                   = yandex_kubernetes_cluster.k8s-cluster.master[0].external_v4_endpoint
    cluster_ca_certificate = yandex_kubernetes_cluster.k8s-cluster.master[0].cluster_ca_certificate
    token                  = data.yandex_client_config.client.iam_token
  }
}

provider "kubernetes" {
  host                   = yandex_kubernetes_cluster.k8s-cluster.master[0].external_v4_endpoint
  cluster_ca_certificate = yandex_kubernetes_cluster.k8s-cluster.master[0].cluster_ca_certificate
  token                  = data.yandex_client_config.client.iam_token
}
