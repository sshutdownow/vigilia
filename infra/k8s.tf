# ==========================================
# Yandex Cloud Managed Service for Kubernetes cluster
# ==========================================

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  description = "Managed Service for Kubernetes cluster"
  name        = var.k8s_cluster_name
  network_id  = yandex_vpc_network.k8s-network.id

  master {
    version   = var.k8s_version
    public_ip = true

    # если зон >= 3, то Regional
    dynamic "regional" {
      for_each = local.is_ha ? [1] : []
      content {
        region = "ru-central1"
        dynamic "location" {
          for_each = yandex_vpc_subnet.k8s-subnets
          content {
            zone      = location.value.zone
            subnet_id = location.value.id
          }
        }
      }
    }

    # Если зон < 3, то Zonal в первой доступной зоне
    dynamic "zonal" {
      for_each = local.is_ha ? [] : [1]
      content {
        zone      = var.net_cidr[0].zone
        subnet_id = yandex_vpc_subnet.k8s-subnets[var.net_cidr[0].zone].id
      }
    }

    security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]

    master_logging {
      enabled                = true
      log_group_id           = yandex_logging_group.log_group_main.id
      audit_enabled          = true
      kube_apiserver_enabled = false
      events_enabled         = true
    }
  }

  service_account_id      = yandex_iam_service_account.k8s-sa.id # Cluster service account ID
  node_service_account_id = yandex_iam_service_account.k8s-node-group-sa.id # Node group service account ID
  
  kms_provider {
    key_id = yandex_kms_symmetric_key.kms-key.id
  }
  
  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_roles,
    yandex_resourcemanager_folder_iam_member.k8s_node_roles,
    yandex_vpc_security_group.gwin
  ]
}

# ==========================================
# Node Group
# ==========================================

resource "yandex_kubernetes_node_group" "k8s-node-group" {
  for_each = { for s in var.net_cidr : s.zone => s }

  description = "Node group for Managed Service for Kubernetes cluster for zone ${each.value.zone}"
  name        = "{var.k8s_node_group_name}-${each.value.zone}"
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  version     = var.k8s_version

  allocation_policy {
    location {
      zone = each.value.zone
    }
  }

  scale_policy {
    auto_scale {
      initial = 1
      min     = 1
      max     = 2
    }
  }

  instance_template {
    name        = "${var.k8s_cluster_name}-{instance.short_id}-{instance_group.id}"
    platform_id = var.platform_id

    network_interface {
      nat                = var.nat
      subnet_ids         = [yandex_vpc_subnet.k8s-subnets[each.value.zone].id]
      security_group_ids = [
        yandex_vpc_security_group.k8s-main-sg.id, 
        yandex_vpc_security_group.gwin.id
      ]
    }

    resources {
      memory        = var.memory
      cores         = var.cores
      core_fraction = var.core_fraction
    }

    boot_disk {
      type = var.disk_type
      size = var.disk_size
    }

    scheduling_policy {
      preemptible = var.vm_preemptible
    }

    metadata = {
      ssh-keys = "${var.vm_user}:${var.ssh_key}"
    }
  }
}
