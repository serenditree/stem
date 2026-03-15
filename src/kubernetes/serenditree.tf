########################################################################################################################
# Serenditree
########################################################################################################################
resource "helm_release" "serenditree" {
  name      = "serenditree"
  chart     = "${var.charts}/tree"
  namespace = "terra-argocd"
  atomic    = true
  wait      = true

  depends_on = [terraform_data.post_vault]
  ######################################################################################################################
  # Values
  ######################################################################################################################
  set = concat(
    [
      {
        name  = "global.context"
        value = var.context
      },
      {
        name  = "global.clusterDomain"
        value = var.cluster_domain
      },
      {
        name  = "global.host"
        value = var.host
      },
      {
        name  = "global.issuer"
        value = var.issuer
      },
      {
        name  = "global.email"
        value = var.email
      },
      {
        name  = "global.stage"
        value = var.stage
      },
      {
        name  = "global.wait"
        value = var.wait
      },
      {
        name  = "global.zone.compute1"
        value = var.zone_compute_1
      },
      {
        name  = "global.zone.storage1"
        value = var.zone_storage_1
      },
      {
        name  = "global.zone.storage2"
        value = var.zone_storage_2
      },
      {
        name  = "terraCilium.enabled"
        value = var.cni == "" ? "true" : "false"
      },
      {
        name  = "terraCilium.parameters.cluster.name"
        value = exoscale_sks_cluster.serenditree.name
      },
      {
        name  = "terraCilium.parameters.k8sServiceHost"
        value = trimprefix(exoscale_sks_cluster.serenditree.endpoint, "https://")
      },
      {
        name  = "terraTraces.parameters.quickwit.config.storage.s3.endpoint"
        value = "https://sos-${var.zone_storage_1}.exo.io"
      },
      {
        name  = "terraTraces.parameters.quickwit.config.storage.s3.region"
        value = var.zone_storage_1
      },
      {
        name  = "terraTraces.parameters.quickwit.config.default_index_root_uri"
        value = "s3://${var.storage_traces}/indexes"
      },
      {
        name  = "rootSeed.parameters.s3.endpoint"
        value = "https://sos-${var.zone_storage_1}.exo.io"
      },
      {
        name  = "rootSeed.parameters.s3.region"
        value = var.zone_storage_1
      }
    ],
    [
      for index, name in keys(var.compute_nodes) : {
        name  = "terraScale.parameters.autoscalingGroupNames[${index}]"
        value = exoscale_sks_nodepool.serenditree[name].id
      }
    ],
    [
      for key, value in var.oidc_parameters : {
        name  = key
        value = value
      }
    ]
  )
}
