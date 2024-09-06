########################################################################################################################
# Init
########################################################################################################################
provider "exoscale" {
  key     = var.api_key
  secret  = var.api_secret
  timeout = 240
}

########################################################################################################################
# Security group
########################################################################################################################
resource "exoscale_security_group" "serenditree" {
  name = "serenditree"
}

resource "exoscale_security_group_rule" "sks_nodes_ccm" {
  security_group_id = exoscale_security_group.serenditree.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = "0.0.0.0/0"
  start_port        = 30000
  end_port          = 32767
}

resource "exoscale_security_group_rule" "sks_nodes_logs" {
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "TCP"
  start_port             = 10250
  end_port               = 10250
}

resource "exoscale_security_group_rule" "calico_traffic" {
  count                  = var.cni == "calico" ? 1 : 0
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "UDP"
  start_port             = 4789
  end_port               = 4789
}

resource "exoscale_security_group_rule" "cilium_healthcheck_tcp" {
  count                  = var.cni == "cilium" || var.cni == "" ? 1 : 0
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "TCP"
  start_port             = 4240
  end_port               = 4240
}

resource "exoscale_security_group_rule" "cilium_healthcheck_ping" {
  count                  = var.cni == "cilium" || var.cni == "" ? 1 : 0
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "ICMP"
  icmp_type              = 8
  icmp_code              = 0
}

resource "exoscale_security_group_rule" "cilium_vxlan" {
  count                  = var.cni == "cilium" || var.cni == "" ? 1 : 0
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "UDP"
  start_port             = 8472
  end_port               = 8472
}

resource "exoscale_security_group_rule" "cilium_hubble" {
  count                  = var.cni == "cilium" || var.cni == "" ? 1 : 0
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "TCP"
  start_port             = 4244
  end_port               = 4244
}

resource "exoscale_security_group_rule" "cilium_prometheus" {
  count                  = var.cni == "cilium" || var.cni == "" ? 1 : 0
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "TCP"
  start_port             = 9962
  end_port               = 9965
}

resource "exoscale_security_group_rule" "cilium_prometheus_node_exporter" {
  count                  = var.cni == "cilium" || var.cni == "" ? 1 : 0
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "TCP"
  start_port             = 9100
  end_port               = 9100
}

########################################################################################################################
# Anti affinity
########################################################################################################################
resource "exoscale_anti_affinity_group" "serenditree" {
  for_each = var.compute_nodes

  name = "serenditree-${each.key}"
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
  exoscale_ccm   = true
  exoscale_csi   = var.csi
  metrics_server = true
  auto_upgrade   = true
}
########################################################################################################################
# Kubeconfig
########################################################################################################################
resource "exoscale_sks_kubeconfig" "sks_kubeconfig" {
  zone       = exoscale_sks_cluster.serenditree.zone
  cluster_id = exoscale_sks_cluster.serenditree.id

  user        = "kubeadmin/serenditree"
  groups      = ["system:masters"]
  ttl_seconds = 2629800
}

resource "local_sensitive_file" "sks_kubeconfig_file" {
  filename        = var.kubeconfig
  content         = exoscale_sks_kubeconfig.sks_kubeconfig.kubeconfig
  file_permission = "0600"
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
