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
      name  = "configs.params.server\\.url"
      value = "https://argocd.${var.domain_name}"
    },    
    {
      name  = "configs.params.server\\.insecure"
      value = "true"
    },
    {
      name  = "server.extraArgs"
      value = "{--insecure}"
    },
    {
      name  = "repoServer.extraArgs"
      value = "{--disable-tls}"
    },
    {
      name  = "configs.params.repo.server.disable.tls"
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
      extraObjects = [
        {
          apiVersion = "networking.k8s.io/v1"
          kind       = "Ingress"
          metadata = {
            name      = "argocd-ingress"
            namespace = "argocd"
            annotations = {
              "gwin.yandex.cloud/groupName"           = "ingress"
              "gwin.yandex.cloud/externalIPv4Address" = yandex_vpc_address.gwin_static_ip.external_ipv4_address[0].address
              "gwin.yandex.cloud/certificateId"       = data.yandex_cm_certificate.le_cert.id
              "gwin.yandex.cloud/securityGroups"      = yandex_vpc_security_group.gwin.id
              "gwin.yandex.cloud/backend-protocol"    = "http"
            }
          }
          spec = {
            ingressClassName = "gwin-default"
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
            tls = [{
              hosts      = ["argocd.${var.domain_name}"]
              secretName = "yc-certmgr-cert-id-${data.yandex_cm_certificate.le_cert.id}"
            }]
          }
        }
      ]
    })
  ]


  depends_on = [
    yandex_kubernetes_cluster.k8s-cluster,
    helm_release.gwin,
    yandex_vpc_security_group.gwin]
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
    url      = var.gitlab_url
    password = var.gitlab_token
    username = var.gitlab_username
  }

  depends_on = [helm_release.argocd]
}
