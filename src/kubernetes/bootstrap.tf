########################################################################################################################
# Helm config
########################################################################################################################
provider "helm" {
  kubernetes = {
    config_path = "${path.root}/${local_sensitive_file.serenditree_kubeconfig_file.filename}"
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
      KUBECONFIG = "${path.root}/${local_sensitive_file.serenditree_kubeconfig_file.filename}"
      CRDS       = var.crds
      CNI        = var.cni
    }
  }
}
########################################################################################################################
# Karpenter
########################################################################################################################
resource "helm_release" "terra_scale" {
  count = var.auto_scaler == "karpenter" ? 1 : 0

  name             = "terra-scale"
  chart            = "${var.charts}/terra/scale"
  namespace        = "kube-system"
  atomic           = true
  wait             = true
  wait_for_jobs    = true

  depends_on = [terraform_data.pre_bootstrap]

  set = [
    {
      name  = "terraScale.karpenter"
      value = "true"
    },
    {
      name  = "terraScale.clusterAutoscaler"
      value = "false"
    },
    {
      name  = "terraScale.securityGroup"
      value = exoscale_security_group.serenditree.id
    },
    {
      name  = "terraScale.privateNetwork"
      value = exoscale_private_network.serenditree.id
    },
    {
      name  = "terraScale.antiAffinityGroup"
      value = exoscale_anti_affinity_group.serenditree["dev"].id
    }
  ]
}
########################################################################################################################
# Cilium
########################################################################################################################
resource "helm_release" "terra_cilium" {
  count = var.cni == "" ? 1 : 0

  name          = "terra-cilium"
  chart         = "${var.charts}/terra/cilium"
  namespace     = "kube-system"
  atomic        = true
  wait          = true
  wait_for_jobs = true

  depends_on = [helm_release.terra_scale]

  set = [
    {
      name  = "cilium.cluster.name"
      value = exoscale_sks_cluster.serenditree.name
    },
    {
      name  = "cilium.k8sServiceHost"
      value = trimprefix(exoscale_sks_cluster.serenditree.endpoint, "https://")
    }
  ]
}
########################################################################################################################
# ArgoCD
########################################################################################################################
resource "helm_release" "terra_argocd" {
  name             = "terra-argocd"
  chart            = "${var.charts}/terra/argocd"
  namespace        = "terra-argocd"
  atomic           = true
  wait             = true
  wait_for_jobs    = true
  create_namespace = true

  depends_on = [helm_release.terra_cilium]
}
########################################################################################################################
# Post argocd
########################################################################################################################
resource "terraform_data" "post_argocd" {
  depends_on = [helm_release.terra_argocd]

  provisioner "local-exec" {
    command = "./src/post-argocd.sh"
    environment = {
      KUBECONFIG = "${path.root}/${local_sensitive_file.serenditree_kubeconfig_file.filename}"
    }
  }
}
########################################################################################################################
# Vault
########################################################################################################################
resource "helm_release" "terra_vault" {
  name             = "terra-vault"
  chart            = "${var.charts}/terra/vault"
  namespace        = "terra-vault"
  atomic           = true
  wait             = true
  wait_for_jobs    = true
  create_namespace = true
  timeout          = 360

  depends_on = [terraform_data.post_argocd]
}
########################################################################################################################
# Post vault
########################################################################################################################
resource "terraform_data" "post_vault" {
  depends_on = [helm_release.terra_vault]

  provisioner "local-exec" {
    command = "./src/post-vault.sh"
    environment = {
      KUBECONFIG = "${path.root}/${local_sensitive_file.serenditree_kubeconfig_file.filename}"
    }
  }
}
