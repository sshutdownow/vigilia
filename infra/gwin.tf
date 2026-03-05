resource "helm_release" "gwin" {
  name             = "gwin"
  repository       = "oci://cr.yandex/yc-marketplace/yandex-cloud/gwin"
  version          = "v1.0.10"
  chart            = "gwin-chart"
  namespace        = "gwin-ns"
  create_namespace = true

  set = [
    {
      name  = "controller.folderId"
      value = var.folder_id
    },
    {
      name  = "controller.ycServiceAccount.secret.value"
      value = file("authorized_key.json")
    }
  ]

  #  values = [
  #    yamlencode({
  #      controller = {
  #        folderId = var.folder_id
  #        ycServiceAccount = {
  #          secret = {
  #            value = file("authorized_key.json")
  #          }
  #        }
  #      }
  #    })
  #  ]

  depends_on = [yandex_kubernetes_node_group.k8s-node-group]
}

resource "yandex_resourcemanager_folder_iam_member" "gwin_roles" {
  for_each = toset([
    "alb.editor",
    "certificate-manager.certificates.downloader",
    "compute.viewer",
    "vpc.publicAdmin",
    "k8s.viewer"
  ])
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
}
