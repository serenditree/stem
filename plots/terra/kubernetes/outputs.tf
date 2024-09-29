########################################################################################################################
# Outputs
########################################################################################################################
output "serenditree_scaler_file" {
  value = local_sensitive_file.serenditree_scaler.filename
}

output "serenditree_data_file" {
  value = local_sensitive_file.serenditree_data.filename
}

output "serenditree_backup_file" {
  value = local_sensitive_file.serenditree_backup.filename
}

output "serenditree_sks_kubeconfig" {
  value = local_sensitive_file.serenditree_sks_kubeconfig_file.filename
}

output "serenditree_sks_endpoint" {
  value = exoscale_sks_cluster.serenditree.endpoint
}
