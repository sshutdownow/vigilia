locals {
  # Количество зон
  cluster_size = length(var.net_cidr)
  # Флаг HA == 3 masters
  is_ha        = local.cluster_size >= 3

  # для Security Group и Node Group
  k8s_zone_v4_cidr_blocks = [for s in var.net_cidr : s.prefix]
  k8s_node_subnet_ids     = [for s in yandex_vpc_subnet.k8s-subnets : s.id]
}
