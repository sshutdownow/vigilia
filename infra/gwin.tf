resource "helm_release" "gwin" {
  name       = "gwin-ingress-controller"
  repository = "https://charts.yc-market.yandex.net"
  chart      = "gwin-ingress-controller"
  namespace  = "kube-system"

  # Используем динамические блоки set (это самый надежный способ)
  dynamic "set" {
    for_each = {
      "folderId"  = var.folder_id
      "clusterId" = yandex_kubernetes_cluster.k8s-cluster.id
    }
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [yandex_kubernetes_node_group.k8s-node-group]
}

resource "yandex_resourcemanager_folder_iam_member" "gwin_roles" {
  for_each = toset([
    "alb.editor",
    "certificate-manager.downloader",
    "compute.viewer",
    "vpc.publicAdmin"
  ])
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${data.yandex_iam_service_account.k8s_sa.id}"
}
