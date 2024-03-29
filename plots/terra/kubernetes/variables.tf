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

variable "ssh_key_pair" {
  description = "Identifier of the ssh public key available at Exoscale."
  type        = string
  default     = "tanwald1"
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
  default     = "1.29.1"
}

variable "service_level" {
  description = "Service level."
  type        = string
  default     = "pro"
}

variable "cni" {
  description = "Container network interface plugin to use."
  type        = string
  default     = "cilium"
}

variable "base_domain" {
  description = "Base domain."
  type        = string
  default     = "serenditree.io"
}
########################################################################################################################
# Nodes
########################################################################################################################
variable "compute_nodes" {
  description = "The compute node-pools to create."
  type = map(object({
    replicas      = number
    instance_type = string
    disk_size     = number
  }))
  default = {
    dev = {
      replicas      = 2
      instance_type = "standard.large"
      disk_size     = 128
    }
  }
}
