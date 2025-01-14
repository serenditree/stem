########################################################################################################################
# Helm config
########################################################################################################################
provider "helm" {
  kubernetes {
    config_path = "${path.module}/${local_sensitive_file.serenditree_kubeconfig_file.filename}"
  }
}
########################################################################################################################
# Pre-bootstrap
########################################################################################################################
resource "terraform_data" "pre_bootstrap" {
  depends_on = [exoscale_sks_nodepool.serenditree]

  provisioner "local-exec" {
    command = "./src/pre-bootstrap.sh"
    environment = {
      KUBECONFIG = "${path.module}/${local_sensitive_file.serenditree_kubeconfig_file.filename}"
    }
  }
}
########################################################################################################################
# Cilium
########################################################################################################################
resource "helm_release" "terra_cilium" {
  count = var.cni == "" ? 1 : 0

  name          = "terra-cilium"
  repository    = "https://helm.cilium.io"
  chart         = "cilium"
  namespace     = "kube-system"
  version       = "1.16.5"
  wait          = true
  wait_for_jobs = true

  depends_on = [terraform_data.pre_bootstrap]

  values = [
    file("${path.root}/rc/cilium.yaml")
  ]

  set {
    name  = "cluster.name"
    value = exoscale_sks_cluster.serenditree.name
  }
  set {
    name  = "k8sServiceHost"
    value = trimprefix(exoscale_sks_cluster.serenditree.endpoint, "https://")
  }
}
########################################################################################################################
# ArgoCD
########################################################################################################################
resource "helm_release" "terra_argocd" {

  name             = "terra-argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "terra-argocd"
  version          = "7.7.15"
  wait             = true
  wait_for_jobs    = true
  create_namespace = true

  depends_on = [helm_release.terra_cilium]

  values = [
    file("${path.root}/rc/argocd.yaml")
  ]
}
########################################################################################################################
# Pre-bootstrap
########################################################################################################################
resource "terraform_data" "post_bootstrap" {
  depends_on = [helm_release.terra_argocd]

  provisioner "local-exec" {
    command = "./src/post-bootstrap.sh"
    environment = {
      KUBECONFIG = "${path.module}/${local_sensitive_file.serenditree_kubeconfig_file.filename}"
    }
  }
}
