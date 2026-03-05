resource "helm_release" "sausage_store_app" {
  count      = false # TODO
  name       = "sausage-store-app"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [
    yamlencode({
      applications = [
        {
          name      = "sausage-store"
          namespace = "argocd"
          project   = "default"
          source = {
            # Pulls from OCI instead of Git
            repoURL        = "cr.yandex/${yandex_container_registry.container-registry.id}"
            chart          = "sausage-store"
            targetRevision = "1.0.0"
            helm = {
              values = yamlencode({
                backend = {
                  image = "cr.yandex/${yandex_container_registry.container-registry.id}/sausage-backend"
                }
                frontend = {
                  image = "cr.yandex/${yandex_container_registry.container-registry.id}/sausage-frontend"
                }
                ingress = {
                  annotations = {
                    "gwin.ingress.kubernetes.io/certificate-id" = yandex_cm_certificate.le_cert.id
                  }
                }
              })
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "sausage-store"
          }
          syncPolicy = {
            automated   = { prune = true, selfHeal = true }
            syncOptions = ["CreateNamespace=true"]
          }
        }
      ]
    })
  ]

  depends_on = [
    yandex_kubernetes_cluster.k8s-cluster,
    helm_release.argocd,
    kubernetes_secret_v1.yc_registry_oci
  ]
}
