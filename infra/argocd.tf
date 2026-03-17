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

  depends_on = [
    yandex_kubernetes_cluster.k8s-cluster,
    helm_release.external_secrets,
    helm_release.vpa,
    helm_release.gwin,
    yandex_vpc_security_group.gwin
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
              - name: "global.sa_id"
                value: "${yandex_iam_service_account.sausage_backend_sa.id}"
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

  depends_on = [
    kubernetes_secret_v1.sausage_repo_gitlab,
    yandex_lockbox_secret_version.v1
  ]
}

resource "kubernetes_namespace_v1" "sausage_store" {
  metadata {
    name = "sausage-store"
  }
}

# login/password for k8s to download images from GitLab 
resource "kubernetes_secret_v1" "gitlab_pull_secret" {
  metadata {
    name      = "gitlab-pull-secret"
    # namespace = "sausage-store"
    namespace = kubernetes_namespace_v1.sausage_store.metadata[0].name
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (replace(var.gitlab_image_url, "/^https?:\\/\\/|(\\/.*)$/", "")) = {
          auth = base64encode("${var.gitlab_username}:${var.gitlab_token}")
        }
      }
    })
  }
}
