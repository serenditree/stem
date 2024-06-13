########################################################################################################################
# Platform
########################################################################################################################
variable "api_key" {
  description = "Exoscale api key."
  type        = string
}

variable "api_secret" {
  description = "Exoscale api secret."
  type        = string
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
  default     = "1.29.5"
}

variable "service_level" {
  description = "Service level."
  type        = string
  default     = "pro"
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
      replicas      = 2
      instance_type = "standard.large"
      disk_size     = 32
    }
  }
}

########################################################################################################################
# Config
########################################################################################################################
variable "kubeconfig" {
  description = "Target location of kubeconfig"
  type        = string
  default     = ""
}
