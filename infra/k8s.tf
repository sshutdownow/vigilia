# Infrastructure for Yandex Cloud Managed Service for Kubernetes cluster and Container Registry
#
# RU: https://cloud.yandex.ru/docs/managed-kubernetes/tutorials/marketplace/argo-cd
# EN: https://cloud.yandex.com/en/docs/managed-kubernetes/tutorials/marketplace/argo-cd

# Set the configuration of Managed Service for Kubernetes cluster and Container Registry
locals {
  cloud_id      = var.cloud_id
  folder_id     = var.folder_id               # Your cloud folder ID, same as for provider
  k8s_version   = var.k8s_version             # Desired version of Kubernetes. For available versions, see the documentation main page: https://cloud.yandex.com/en/docs/managed-kubernetes/concepts/release-channels-and-updates.
  sa_k8s        = var.sa_k8s                  # Service account name for Kubernetes cluster. It must be unique in a cloud.
  sa_k8s_node   = var.sa_k8s_node_group
  registry_name = var.container_registry_name # Container Registry name.

  # The following settings are predefined. Change them only if necessary.
  network_name             = "k8s-network"         # Name of the network
  subnet_name              = "subnet-a"            # Name of the subnet
  zone_a_v4_cidr_blocks    = "10.1.0.0/16"         # CIDR block for the subnet in the ru-central1-a availability zone
  main_security_group_name = "k8s-main-sg"         # Name of the main security group of the cluster
  public_services_sg_name  = "k8s-public-services" # Name of the public services security group for node groups
  k8s_cluster_name         = "k8s-cluster"         # Name of the Kubernetes cluster
  k8s_node_group_name      = "k8s-node-group"      # Name of the Kubernetes node group
}

resource "yandex_vpc_network" "k8s-network" {
  description = "Network for the Managed Service for Kubernetes cluster"
  name        = local.network_name
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in ru-central1-a availability zone"
  name           = local.subnet_name
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_gateway" "nat-gateway" {
  folder_id = var.folder_id
  name      = "NAT-gateway-{local.network_name}"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  folder_id = var.folder_id
  name      = "NAT-route-table-{local.subnet_name}"
  network_id = yandex_vpc_network.k8s-network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat-gateway.id
  }
}

resource "yandex_vpc_address" "gwin_static_ip" {
  name = "gwin-static-ip"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

resource "yandex_vpc_security_group" "k8s-main-sg" {
  description = "Security group ensure the basic performance of the cluster. Apply it to the cluster and node groups."
  name        = local.main_security_group_name
  network_id  = yandex_vpc_network.k8s-network.id

  ingress {
    description    = "The rule allows availability checks from the load balancer's range of addresses. It is required for the operation of a fault-tolerant cluster and load balancer services."
    protocol       = "TCP"
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"] # The load balancer's address range
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    description       = "The rule allows the master-node and node-node interaction within the security group"
    protocol          = "ANY"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    description    = "The rule allows the pod-pod and service-service interaction. Specify the subnets of your cluster and services."
    protocol       = "ANY"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    description    = "The rule allows receipt of debugging ICMP packets from internal subnets"
    protocol       = "ICMP"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
  }

  ingress {
    description    = "The rule allows connection to Kubernetes API on 6443 port from specified network"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }

  ingress {
    description    = "The rule allows connection to Kubernetes API on 443 port from specified network"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    description    = "The rule allows connection to Git repository by SSH on 22 port from the Internet"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    description    = "The rule allows HTTP traffic"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    description    = "The rule allows connection to Yandex Container Registry on 5050 port"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5050
  }

  egress {
    description    = "The rule allows all outgoing traffic. Nodes can connect to Yandex Container Registry, Object Storage, Docker Hub, and more."
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "k8s-public-services" {
  description = "Security group allows connections to services from the internet. Apply the rules only for node groups."
  name        = local.public_services_sg_name
  network_id  = yandex_vpc_network.k8s-network.id

  ingress {
    description    = "The rule allows incoming traffic from the internet to the NodePort port range. Add ports or change existing ones to the required ports."
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }
}

resource "yandex_iam_service_account" "k8s-sa" {
  description = "Service account to manage the Kubernetes cluster and node group"
  name        = local.sa_k8s
}

resource "yandex_iam_service_account" "k8s-node-group-sa" {
	description = "Service account to manage the Kubernetes node group"
  name        = local.sa_k8s_node
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  description = "Managed Service for Kubernetes cluster"
  name        = local.k8s_cluster_name
  network_id  = yandex_vpc_network.k8s-network.id

  master {
    version = local.k8s_version
    master_location {
      zone      = yandex_vpc_subnet.subnet-a.zone
      subnet_id = yandex_vpc_subnet.subnet-a.id
    }

    public_ip = true

    security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]

    master_logging {
      enabled = true
      log_group_id = "${yandex_logging_group.log_group_main.id}"
      audit_enabled = true
      kube_apiserver_enabled = false
      cluster_autoscaler_enabled = false
      events_enabled = true
    }
  }
  service_account_id      = yandex_iam_service_account.k8s-sa.id # Cluster service account ID
  node_service_account_id = yandex_iam_service_account.k8s-node-group-sa.id # Node group service account ID
  
  kms_provider {
    key_id = yandex_kms_symmetric_key.kms-key.id
  }
  
  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_roles,
    yandex_resourcemanager_folder_iam_member.k8s_node_roles
  ]
}

resource "yandex_kubernetes_node_group" "k8s-node-group" {
  description = "Node group for Managed Service for Kubernetes cluster"
  name        = local.k8s_node_group_name
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  version     = local.k8s_version

  scale_policy {
    fixed_scale {
      size = 1 # Number of hosts
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }

  instance_template {
    name        = "{local.k8s_cluster_name}-{instance.short_id}-{instance_group.id}"
    platform_id = var.platform_id

    network_interface {
      nat                = var.nat
      subnet_ids         = [yandex_vpc_subnet.subnet-a.id]
      security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id, yandex_vpc_security_group.k8s-public-services.id]
    }

    resources {
      memory        = var.memory # RAM quantity in GB
      cores         = var.cores  # Number of CPU cores
      core_fraction = var.core_fraction
    }

    boot_disk {
      type = var.disk_type
      size = var.disk_size
    }

    scheduling_policy {
      preemptible = var.vm_preemptible
    }
  }

  depends_on = [yandex_vpc_security_group.gwin]
}

# Container Registry
resource "yandex_container_registry" "container-registry" {
  name      = local.registry_name
  folder_id = var.folder_id
}
