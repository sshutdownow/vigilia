locals {
  gitlab_registry = replace(var.gitlab_image_url, "/^https?:\\/\\/|(\\/.*)$/", "")
}

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
      name  = "configs.secret.argocdServerAdminPassword"
      value = bcrypt_hash.argocd_password.id
    },
    { # GWIN
      name  = "server.service.type"
      value = "NodePort"
    },
    { # разрешить запросы из Helm к k8s
      name  = "configs.cm.helm\\.enable\\.lookup"
      value = "true"
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
              "gwin.yandex.cloud/securityGroups"      = yandex_vpc_security_group.gwin.id
              "gwin.yandex.cloud/logs.logGroupId"     = yandex_logging_group.log_group_main.id
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
        },
        {
          apiVersion = "autoscaling.k8s.io/v1"
          kind       = "VerticalPodAutoscaler"
          metadata = {
            name      = "argocd-server-vpa"
            namespace = "argocd"
          }
          spec = {
            targetRef = {
              apiVersion = "apps/v1"
              kind       = "Deployment"
              name       = "argocd-server"
            }
            updatePolicy = {
              updateMode = "Auto"
            }
          }
        }
      ]
    })
  ]

  cleanup_on_fail = true
  force_update    = true
  recreate_pods   = true
  wait            = true
  timeout         = 900

  depends_on = [
    yandex_kubernetes_node_group.k8s-node-group,
    helm_release.external_secrets,
    helm_release.vpa,
    yandex_vpc_security_group.gwin,
    helm_release.gwin
  ]
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
    url      = var.gitlab_git_url
    password = var.gitlab_token
    username = var.gitlab_username
  }

  depends_on = [helm_release.argocd]
}

# ArgoCD root application
resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"
  version    = "2.0.4"

  values = [
    <<-EOT
    applications:
      root-management:
        namespace: argocd
        finalizers:
          - resources-finalizer.argocd.argoproj.io
        project: default
        source:
          repoURL: "${var.gitlab_git_url}"
          path: argocd-management
          targetRevision: master
          helm:
            parameters:
              - name: "global.folder_id"
                value: "${var.folder_id}"
              - name: "global.repo_url"
                value: "${var.gitlab_git_url}"
              - name: "global.gitlab_registry"
                value: "${local.gitlab_registry}"
              - name: "global.gitlab_user"
                value: "${var.gitlab_username}"
              - name: "global.gitlab_token"
                value: "${var.gitlab_token}"
              - name: "global.sa_id"
                value: "${yandex_iam_service_account.eso_sa.id}"
              - name: "global.lockbox_secret_id"
                value: "${yandex_lockbox_secret.sausage_store_secrets.id}"
              - name: "global.gwin_ip"
                value: "${yandex_vpc_address.gwin_static_ip.external_ipv4_address[0].address}"
              - name: "global.gwin_sg"
                value: "${yandex_vpc_security_group.gwin.id}"
              - name: "global.certificate_id"
                value: "${data.yandex_cm_certificate.le_cert.id}"
        destination:
          server: https://kubernetes.default.svc
          namespace: argocd
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
    EOT
  ]

  cleanup_on_fail = true
  force_update    = true
  recreate_pods   = true
  wait            = true

  depends_on = [
    kubernetes_secret_v1.sausage_repo_gitlab,
    yandex_lockbox_secret_version.v1
  ]
}
