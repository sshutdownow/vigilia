resource "bcrypt_hash" "argocd_password" {
  cleartext = var.argocd_admin_password
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
    helm_release.gwin,
    yandex_vpc_security_group.gwin,
    helm_release.vpa,
    kubernetes_secret_v1.gitlab_pull_secret
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
        destination:
          server: https://kubernetes.default.svc
          namespace: argocd
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
    EOT
  ]
  depends_on = [helm_release.argocd]
}

resource "kubernetes_role_v1" "argocd_read_config" {
  metadata {
    name      = "argocd-read-config"
    namespace = "sausage-store"
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "argocd_read_config_binding" {
  metadata {
    name      = "argocd-read-config-binding"
    namespace = "sausage-store"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "argocd-read-config"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argocd-repo-server"
    namespace = "argocd"
  }
}

resource "kubernetes_manifest" "sausage_store_app" {
  count = 0
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "sausage-store"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = tostring(var.gitlab_git_url)
        path           = "deploy-yandex-cloud"
        targetRevision = "master"
        helm = {
          releaseName = "sausage-store"
          parameters = [
            {
              name  = "ingress.gwin_ip"
              value = tostring(yandex_vpc_address.gwin_static_ip.external_ipv4_address[0].address)
            },
            {
              name  = "ingress.gwin_sg"
              value = tostring(yandex_vpc_security_group.gwin.id)
            },
            {
              name  = "ingress.certificate_id"
              value = tostring(data.yandex_cm_certificate.le_cert.id)
            }
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "sausage-store"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.sausage_store,
    helm_release.argocd
  ]
}

resource "kubernetes_config_map_v1" "infra_info" {
  metadata {
    name      = "infra-info"
    namespace = "argocd"
  }

  data = {
    "values.yaml" = <<-EOT
      sausage-store:
        ingress:
          gwin_ip: "${yandex_vpc_address.gwin_static_ip.external_ipv4_address[0].address}"
          gwin_sg: "${yandex_vpc_security_group.gwin.id}"
          certificate_id: "${data.yandex_cm_certificate.le_cert.id}"
    EOT
  }
  
  depends_on = [helm_release.argocd]
}
