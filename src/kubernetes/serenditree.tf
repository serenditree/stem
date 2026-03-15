########################################################################################################################
# Serenditree
########################################################################################################################
resource "helm_release" "serenditree" {
  name      = "serenditree"
  chart     = "${path.module}/../../charts/tree"
  namespace = "terra-argocd"
  wait      = true

  depends_on = [
    terraform_data.post_bootstrap,
    aws_s3_bucket.serenditree_traces,
    exoscale_iam_api_key.serenditree_data,
    exoscale_iam_api_key.serenditree_scaler,
    exoscale_iam_api_key.serenditree_traces
  ]
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
        name  = "global.stage"
        value = var.stage
      },
      {
        name  = "global.zone"
        value = var.zone
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
        name  = "terraTraces.parameters.quickwit.config.default_index_root_uri"
        value = "s3://${var.storage_traces}/indexes"
      }
    ],
    [
      for index, name in keys(var.compute_nodes) : {
        name  = "terraScale.parameters.autoscalingGroupNames[${index}]"
        value = exoscale_sks_nodepool.serenditree[name].id
      }
    ],
    [
  ######################################################################################################################
  # TODO Sensitive Values
  ######################################################################################################################
      for key, value in var.app_parameters : {
        name  = key
        value = value
      }
    ],
    [
      for key, value in var.cicd_parameters : {
        name  = key
        value = value
      }
    ],
    [
      for key, value in var.o11y_parameters : {
        name  = key
        value = value
      }
    ],
    [
      for key, value in var.oidc_parameters : {
        name  = key
        value = value
      }
    ],
    [
      {
        name  = "terraTraces.parameters.quickwit.config.storage.s3.access_key_id"
        value = exoscale_iam_api_key.serenditree_traces.key
      },
      {
        name  = "terraTraces.parameters.quickwit.config.storage.s3.secret_access_key"
        value = exoscale_iam_api_key.serenditree_traces.secret
      },
      {
        name  = "terraScale.parameters.apikey"
        value = exoscale_iam_api_key.serenditree_scaler.key
      },
      {
        name  = "terraScale.parameters.secret"
        value = exoscale_iam_api_key.serenditree_scaler.secret
      },
      {
        name  = "rootMap.parameters.data.apikey"
        value = exoscale_iam_api_key.serenditree_data.key
      },
      {
        name  = "rootMap.parameters.data.secret"
        value = exoscale_iam_api_key.serenditree_data.secret
      },
      {
        name  = "rootUser.parameters.backup.apikey"
        value = exoscale_iam_api_key.serenditree_backup["user"].key
      },
      {
        name  = "rootUser.parameters.backup.secret"
        value = exoscale_iam_api_key.serenditree_backup["user"].secret
      },
      {
        name  = "rootSeed.parameters.backup.accessKey"
        value = exoscale_iam_api_key.serenditree_backup["seed"].key
      },
      {
        name  = "rootSeed.parameters.backup.accessSecret"
        value = exoscale_iam_api_key.serenditree_backup["seed"].secret
      },
      {
        name  = "terraCerts.parameters.dns.key"
        value = var.issuer_dns ? exoscale_iam_api_key.serenditree_dns[0].key : "disabled"
      },
      {
        name  = "terraCerts.parameters.dns.secret"
        value = var.issuer_dns ? exoscale_iam_api_key.serenditree_dns[0].secret : "disabled"
      }
    ]
  )
}
