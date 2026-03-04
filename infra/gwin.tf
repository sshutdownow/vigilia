resource "helm_release" "gwin" {
  name       = "gwin"
  repository = "oci://cr.yandex/yc-marketplace/yandex-cloud/gwin/gwin-chart"
  version    = "v1.0.10"
  chart      = "gwin-ingress-controller"
  namespace  = "kube-system"

  set = [
    {
      name  = "folderId"
      value = var.folder_id
    },
    {
      name  = "clusterId"
      value = yandex_kubernetes_cluster.k8s-cluster.id
    }
  ]

  depends_on = [yandex_kubernetes_node_group.k8s-node-group]
}

resource "yandex_resourcemanager_folder_iam_member" "gwin_roles" {
  for_each = toset([
    "alb.editor",
    "certificate-manager.downloader",
    "compute.viewer",
    "vpc.publicAdmin",
    "k8s.viewer"
  ])
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${data.yandex_iam_service_account.k8s_sa.id}"
}
