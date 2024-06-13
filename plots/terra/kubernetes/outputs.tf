output "sks_endpoint" {
  value = exoscale_sks_cluster.serenditree.endpoint
}

output "sks_kubeconfig" {
  value = local_sensitive_file.sks_kubeconfig_file.filename
}
