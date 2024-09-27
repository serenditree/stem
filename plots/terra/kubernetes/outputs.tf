########################################################################################################################
# Outputs
########################################################################################################################
output "serenditree_scaler_key" {
  value = exoscale_iam_api_key.serenditree_scaler.key
}

output "serenditree_scaler_secret" {
  value     = exoscale_iam_api_key.serenditree_scaler.secret
  sensitive = true
}

output "serenditree_scaler_file" {
  value = local_sensitive_file.serenditree_scaler.filename
}

output "serenditree_sks_endpoint" {
  value = exoscale_sks_cluster.serenditree.endpoint
}

output "serenditree_sks_kubeconfig" {
  value = local_sensitive_file.serenditree_sks_kubeconfig_file.filename
}
