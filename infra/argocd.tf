resource "bcrypt_hash" "argocd_password" {
  cleartext = var.argocd_admin_password
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  set = [
    {
      name  = "configs.params.server\\.insecure"
      value = "true"
    },
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = bcrypt_hash.argocd_password.id
    },
    { # GWIN
      name  = "server.service.type"
      value = "NodePort"
    }
  ]

  values = [
    yamlencode({
      server = {
        extraObjects = [
          {
            apiVersion = "networking.k8s.io/v1"
            kind       = "Ingress"
            metadata = {
              name = "argocd-ingress"
              annotations = {
                "gwin.yandex.cloud/groupName"           = "ingress"
                "gwin.yandex.cloud/subnets"             = yandex_vpc_subnet.subnet-a.id
                "gwin.yandex.cloud/externalIPv4Address" = yandex_vpc_address.gwin_static_ip.external_ipv4_address.address
                "gwin.yandex.cloud/certificateId"       = yandex_cm_certificate.le_cert.id
                "gwin.yandex.cloud/securityGroups"      = yandex_vpc_security_group.gwin[0].id
                "gwin.yandex.cloud/redirect.argo-redirect.replaceScheme" = "https"
              }
            }
            spec = {
              ingressClassName = "alb"
              rules = [{
                host = "argocd.${var.domain_name}"
                http = {
                  paths = [{
                    path     = "/"
                    pathType = "Prefix"
                    backend = {
                      service = {
                        name = "argocd-server"
                        port = { number = 80 }
                      }
                    }
                  }]
                }
              }]
            }
          }
        ]
      }
    })
  ]

  depends_on = [yandex_kubernetes_cluster.k8s-cluster, helm_release.gwin]
}

resource "kubernetes_secret_v1" "yc_registry_oci" {
  metadata {
    name      = "yc-registry-oci"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type      = "helm"
    name      = "yc-oci"
    enableOCI = "true"
    # Reference your existing registry resource
    url      = "cr.yandex/${yandex_container_registry.container-registry.id}"
    username = "json_key"
    password = file("authorized_key.json")
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret_v1" "sausage_repo_gitlab" {
  metadata {
    name      = "sausage-repo-gitlab"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type     = "git"
    url      = "https://cloud-services-engineer.gitlab.yandexcloud.net"
    password = var.gitlab_access_token
    username = "gitops-bot"
  }

  depends_on = [helm_release.argocd]
}
