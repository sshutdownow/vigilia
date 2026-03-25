# ==================================
# Terraform & Provider Configuration
# ==================================

terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }
    bcrypt = {
      source = "viktorradnai/bcrypt"
    }
  }

  #
  # https://docs.gitlab.com/ci/variables/predefined_variables/
  # CI_PROJECT_ID - The ID of the current project. This ID is unique across all projects on the GitLab instance.
  #
  backend "http" {
    address        = "https://cloud-services-engineer.gitlab.yandexcloud.net/api/v4/projects/${CI_PROJECT_ID}/terraform/state/tfstate"
    lock_address   = "https://cloud-services-engineer.gitlab.yandexcloud.net/api/v4/projects/${CI_PROJECT_ID}/terraform/state/tfstate/lock"
    unlock_address = "https://cloud-services-engineer.gitlab.yandexcloud.net/api/v4/projects/${CI_PROJECT_ID}/terraform/state/tfstate/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
    username       = "${GITLAB_USER_NAME}"
    password       = "${TF_HTTP_PASSWORD}"
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
