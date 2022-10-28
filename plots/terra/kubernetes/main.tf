########################################################################################################################
# Init
########################################################################################################################
provider "exoscale" {
  key            = var.api_key
  secret         = var.api_secret
  timeout        = 120
  gzip_user_data = false
}

data "exoscale_domain" "base" {
  name = var.base_domain
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
  count                  = var.cni == "cilium" ? 1 : 0
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "TCP"
  start_port             = 4240
  end_port               = 4240
}

resource "exoscale_security_group_rule" "cilium_healthcheck_ping" {
  count                  = var.cni == "cilium" ? 1 : 0
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "ICMP"
  icmp_type              = 8
  icmp_code              = 0
}

resource "exoscale_security_group_rule" "cilium_vxlan" {
  count                  = var.cni == "cilium" ? 1 : 0
  security_group_id      = exoscale_security_group.serenditree.id
  user_security_group_id = exoscale_security_group.serenditree.id
  type                   = "INGRESS"
  protocol               = "UDP"
  start_port             = 8472
  end_port               = 8472
}
########################################################################################################################
# Anti affinity
########################################################################################################################
resource "exoscale_affinity" "serenditree" {
  for_each = var.compute_nodes

  name = "serenditree-${each.key}"
  type = "host anti-affinity"
}
########################################################################################################################
# Cluster
########################################################################################################################
resource "exoscale_sks_cluster" "serenditree" {
  name          = "serenditree"
  version       = var.kubernetes_version
  cni           = var.cni
  zone          = var.zone
  service_level = var.service_level
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

  anti_affinity_group_ids = [exoscale_affinity.serenditree[each.key].id]
  security_group_ids      = [exoscale_security_group.serenditree.id]
}
########################################################################################################################
# Wait for cluster
########################################################################################################################
resource "null_resource" "wait_for_cluster" {
  depends_on = [exoscale_sks_nodepool.serenditree]

  provisioner "local-exec" {
    command = "until curl -ks ${exoscale_sks_cluster.serenditree.endpoint}/healthz; do sleep 5s; done"
  }
}
