########################################################################################################################
# Outputs
########################################################################################################################
output "serenditree_backup_file" {
  value = local_sensitive_file.serenditree_backup.filename
}

output "serenditree_data_file" {
  value = local_sensitive_file.serenditree_data.filename
}

output "serenditree_scaler_file" {
  value = local_sensitive_file.serenditree_scaler.filename
}

output "serenditree_traces_file" {
  value = local_sensitive_file.serenditree_traces.filename
}

output "serenditree_endpoint" {
  value = exoscale_sks_cluster.serenditree.endpoint
}
