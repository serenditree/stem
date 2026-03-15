########################################################################################################################
# Platform
########################################################################################################################
variable "api_key" {
  description = "Exoscale api key."
  type        = string
  sensitive   = true
}
variable "api_secret" {
  description = "Exoscale api secret."
  type        = string
  sensitive   = true
}
########################################################################################################################
# Cluster
########################################################################################################################
variable "zone" {
  description = "Target zone."
  type        = string
  default     = "at-vie-1"
}
variable "kubernetes_version" {
  description = "Kubernetes version."
  type        = string
  default     = ""
}
variable "service_level" {
  description = "Service level."
  type        = string
  default     = "pro"
}
variable "auto_upgrade" {
  description = "Auto-upgrade Kubernetes to the latest patch release."
  type        = string
  default     = true
}
variable "cni" {
  description = "Container network interface plugin to use."
  type        = string
  default     = ""
}
variable "csi" {
  description = "Enable container storage interface plugin."
  type        = bool
  default     = true
}
########################################################################################################################
# Nodes
########################################################################################################################
variable "compute_nodes" {
  description = "The node-pools to create."
  type = map(object({
    replicas      = number
    instance_type = string
    disk_size     = number
  }))
  default = {
    dev = {
      replicas      = 3
      instance_type = "standard.large"
      disk_size     = 32
    }
  }
}
########################################################################################################################
# Storage
########################################################################################################################
variable "storage_data" {
  description = "Bucket name for map data."
  type = string
  default = "serenditree-data"
}
variable "storage_data_create" {
  description = "Creates bucket only if set to true."
  type = bool
  default = false
}
variable "storage_backup" {
  description = "Bucket name for map data."
  type = string
  default = "serenditree-backup"
}
variable "storage_backup_create" {
  description = "Creates bucket only if set to true."
  type = bool
  default = false
}
variable "storage_traces" {
  description = "Bucket name for traces and logs."
  type        = string
  default     = "serenditree-traces"
}
########################################################################################################################
# Global
########################################################################################################################
variable "context" {
  description = "Kubernetes context to use."
  type        = string
}
variable "host" {
  description = "Hostname for endpoints."
  type        = string
}
variable "cluster_domain" {
  description = "Kubernetes cluster domain."
  type        = string
  default     = "cluster.local"
}
variable "issuer" {
  description = "Let's encrypt issuer type."
  type        = string
  validation {
    condition     = contains(["staging", "prod"], var.issuer)
    error_message = "Valid values for issuer: {staging,prod}."
  }
}
variable "stage" {
  description = "Target stage."
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.stage)
    error_message = "Valid values for stage: {dev,test,prod}."
  }
}
########################################################################################################################
# Helm Sensitive
########################################################################################################################
variable "app_parameters" {
  description = "Sensitive app parameters."
  type        = map(string)
  sensitive   = true
}
variable "cicd_parameters" {
  description = "Sensitive CI/CD parameters."
  type        = map(string)
  sensitive   = true
}
variable "o11y_parameters" {
  description = "Sensitive observability parameters."
  type        = map(string)
  sensitive   = true
}
variable "oidc_parameters" {
  description = "Sensitive OIDC parameters."
  type        = map(string)
  sensitive   = true
}
