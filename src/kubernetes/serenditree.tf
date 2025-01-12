########################################################################################################################
# Serenditree
########################################################################################################################
resource "helm_release" "serenditree" {
  name          = "serenditree"
  chart         = "${path.module}/../../charts/tree"
  namespace     = "terra-argocd"
  wait          = true

  depends_on = [
    terraform_data.post_bootstrap,
    aws_s3_bucket.serenditree_traces,
    exoscale_iam_api_key.serenditree_data,
    exoscale_iam_api_key.serenditree_scaler,
    exoscale_iam_api_key.serenditree_traces
  ]
  ######################################################################################################################
  # Global
  ######################################################################################################################
  set {
    name  = "global.context"
    value = var.context
  }
  set {
    name  = "global.clusterDomain"
    value = var.cluster_domain
  }
  set {
    name  = "global.host"
    value = var.host
  }
  set {
    name  = "global.issuer"
    value = var.issuer
  }
  set {
    name  = "global.stage"
    value = var.stage
  }
  set {
    name  = "global.zone"
    value = var.zone
  }
  ######################################################################################################################
  # Sensitive
  ######################################################################################################################
  dynamic "set_sensitive" {
    for_each = nonsensitive(var.app_parameters)
    iterator = app_parameter
    content {
      name  = app_parameter.key
      value = app_parameter.value
    }
  }
  dynamic "set_sensitive" {
    for_each = nonsensitive(var.cicd_parameters)
    iterator = cicd_parameter
    content {
      name  = cicd_parameter.key
      value = cicd_parameter.value
    }
  }
  dynamic "set_sensitive" {
    for_each = nonsensitive(var.oidc_parameters)
    iterator = oidc_parameter
    content {
      name  = oidc_parameter.key
      value = oidc_parameter.value
    }
  }
  ######################################################################################################################
  # Cilium
  ######################################################################################################################
  set {
    name  = "terraCilium.parameters.cluster.name"
    value = exoscale_sks_cluster.serenditree.name
  }
  set {
    name  = "terraCilium.parameters.k8sServiceHost"
    value = trimprefix(exoscale_sks_cluster.serenditree.endpoint, "https://")
  }
  ######################################################################################################################
  # Traces
  ######################################################################################################################
  set_sensitive {
    name  = "terraTraces.parameters.config.storage.s3.access_key_id"
    value = exoscale_iam_api_key.serenditree_traces.key
  }
  set_sensitive {
    name  = "terraTraces.parameters.config.storage.s3.secret_access_key"
    value = exoscale_iam_api_key.serenditree_traces.secret
  }
  set {
    name  = "terraTraces.parameters.config.metastore_uri"
    value = "s3://${var.traces}/metastore"
  }
  set {
    name  = "terraTraces.parameters.config.default_index_root_uri"
    value = "s3://${var.traces}/indexes"
  }
  ######################################################################################################################
  # Scale
  ######################################################################################################################
  set_sensitive {
    name  = "terraScale.parameters.apikey"
    value = exoscale_iam_api_key.serenditree_scaler.key
  }
  set_sensitive {
    name  = "terraScale.parameters.secret"
    value = exoscale_iam_api_key.serenditree_scaler.secret
  }
  dynamic "set" {
    for_each = { for index, name in keys(var.compute_nodes) : index => name }
    iterator = node
    content {
      name  = "terraScale.parameters.autoscalingGroups[${node.key}]"
      value = exoscale_sks_nodepool.serenditree[node.value].id
    }
  }
  ######################################################################################################################
  # Map
  ######################################################################################################################
  set_sensitive {
    name  = "rootMap.parameters.data.apikey"
    value = exoscale_iam_api_key.serenditree_data.key
  }
  set_sensitive {
    name  = "rootMap.parameters.data.secret"
    value = exoscale_iam_api_key.serenditree_data.secret
  }
}
