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

variable "service_level" {
  description = "Service level."
  type        = string
  default     = "starter"
}

variable "cni" {
  description = "Container network interface plugin to use."
  type        = string
  default     = "calico"
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
    template_id   = string
    instance_type = string
    disk_size     = number
  }))
  default = {
    dev = {
      replicas      = 2
      template_id   = "dde12e2f-0fc0-4d89-b4e8-07d97ce5a966"
      instance_type = "standard.large"
      disk_size     = 128
    }
  }
}
