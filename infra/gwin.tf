# Сервисный аккаунт для Gwin
resource "yandex_iam_service_account" "gwin_sa" {
  name = "gwin-sa"
  description = "service account for gwin"
}

# Назначение ролей
resource "yandex_resourcemanager_folder_iam_member" "gwin_roles" {
  for_each = toset([
    "alb.editor",
    "load-balancer.admin",
    "certificate-manager.certificates.downloader",
    "certificate-manager.editor",
    "compute.viewer",
    "vpc.user",
    "k8s.viewer",
    "logging.writer"
  ])
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.gwin_sa.id}"
}

resource "yandex_iam_service_account_key" "gwin_sa_key" {
  service_account_id = yandex_iam_service_account.gwin_sa.id
  description        = "Key for Gwin controller"
  key_algorithm      = "RSA_2048"
}

resource "helm_release" "gwin" {
  name             = "gwin"
  repository       = "oci://cr.yandex/yc-marketplace/yandex-cloud/gwin"
  version          = "v1.0.10"
  chart            = "gwin-chart"
  namespace        = "gwin"
  create_namespace = true

  values = [<<-EOF
    controller:
      folderId: ${var.folder_id}
      defaultBalancerSubnets: ["${yandex_vpc_subnet.subnet-a.id}"]
      ycServiceAccount:
        secret:
          value: |
            ${jsonencode({
              "id"                 : yandex_iam_service_account_key.gwin_sa_key.id,
              "service_account_id" : yandex_iam_service_account_key.gwin_sa_key.service_account_id,
              "created_at"         : yandex_iam_service_account_key.gwin_sa_key.created_at,
              "key_algorithm"      : yandex_iam_service_account_key.gwin_sa_key.key_algorithm,
              "public_key"         : yandex_iam_service_account_key.gwin_sa_key.public_key,
              "private_key"        : yandex_iam_service_account_key.gwin_sa_key.private_key
            })}
    gatewayClass:
      create: true
      name: gwin-default
  EOF
  ]
 
  depends_on = [
    yandex_resourcemanager_folder_iam_member.gwin_roles,
    yandex_iam_service_account_key.gwin_sa_key,
    yandex_kubernetes_cluster.k8s-cluster
  ]
}

resource "yandex_vpc_security_group" "gwin" {
  name        = "k8s-gwin-ingress"
  description = "gwin ingress controller security group"
  network_id  = yandex_vpc_network.k8s-network.id
  folder_id   = var.folder_id
  depends_on  = [ 
    yandex_kubernetes_node_group.k8s-node-group
  ]

  ingress {
    protocol       = "ICMP"
    description    = "ping"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "http"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "https"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol          = "TCP"
    description       = "Availability checks of load balancer"
    predefined_target = "loadbalancer_healthchecks"
#    v4_cidr_blocks = [ "198.18.235.0/24", "198.18.248.0/24" ]
    from_port         = 0
    to_port           = 65535
  }


  egress {
    protocol       = "TCP"
    description    = "Enable traffic from GWIN to K8s services"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
    from_port      = 30000
    to_port        = 32767
  }

  egress {
    protocol       = "TCP"
    description    = "Enable probes from GWIN to K8s"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
    port           = 10501
  }
}
