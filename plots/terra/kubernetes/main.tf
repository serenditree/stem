########################################################################################################################
# Init
########################################################################################################################
provider "exoscale" {
  key     = var.api_key
  secret  = var.api_secret
  timeout = 240
}
########################################################################################################################
# Cluster
########################################################################################################################
resource "exoscale_sks_cluster" "serenditree" {
  name           = "serenditree"
  version        = var.kubernetes_version
  cni            = var.cni
  zone           = var.zone
  service_level  = var.service_level
  auto_upgrade   = var.auto_upgrade
  exoscale_csi   = var.csi
  exoscale_ccm   = true
  metrics_server = true
}
########################################################################################################################
# Kubeconfig
########################################################################################################################
resource "exoscale_sks_kubeconfig" "serenditree_sks_kubeconfig" {
  zone       = exoscale_sks_cluster.serenditree.zone
  cluster_id = exoscale_sks_cluster.serenditree.id

  user        = "kubeadmin/serenditree"
  groups      = ["system:masters"]
  ttl_seconds = 2629800
}

resource "local_sensitive_file" "serenditree_sks_kubeconfig_file" {
  filename        = var.kubeconfig
  content         = exoscale_sks_kubeconfig.serenditree_sks_kubeconfig.kubeconfig
  file_permission = "0600"
}
########################################################################################################################
# Anti affinity
########################################################################################################################
resource "exoscale_anti_affinity_group" "serenditree" {
  for_each = var.compute_nodes

  name = "serenditree-${each.key}"
}
########################################################################################################################
# Compute nodes
########################################################################################################################
resource "exoscale_sks_nodepool" "serenditree" {
  for_each = var.compute_nodes

  zone            = var.zone
  cluster_id      = exoscale_sks_cluster.serenditree.id
  name            = "serenditree-${each.key}"
  instance_type   = each.value.instance_type
  size            = each.value.replicas
  disk_size       = each.value.disk_size
  instance_prefix = "serenditree-${each.key}"

  labels = {
    "serenditree.io/stage" = each.key
  }

  anti_affinity_group_ids = [exoscale_anti_affinity_group.serenditree[each.key].id]
  security_group_ids      = [exoscale_security_group.serenditree.id]
}
########################################################################################################################
# Wait for cluster
########################################################################################################################
resource "null_resource" "wait_for_cluster" {
  depends_on = [exoscale_sks_nodepool.serenditree]

  provisioner "local-exec" {
    command = "until curl -ks ${exoscale_sks_cluster.serenditree.endpoint}/healthz; do sleep 2s; done"
  }
}
