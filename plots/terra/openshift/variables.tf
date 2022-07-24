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

variable "base_domain" {
  description = "Base domain."
  type        = string
  default     = "serenditree.io"
}

variable "cluster_name" {
  description = "Cluster name."
  type        = string
  default     = "dev"
}
########################################################################################################################
# Nodes
########################################################################################################################
variable "bootstrap_enabled" {
  description = "Flag to set bootstrap mode."
  type        = bool
  default     = true
}

variable "worker_nodes_enabled" {
  description = "Flag to enable worker nodes."
  type        = bool
  default     = false
}

variable "master_nodes" {
  description = "The master nodes to create."
  type = object({
    name           = string
    replicas       = number
    hyperthreading = string
    template_id    = string
    instance_type  = string
    disk_size      = number
  })
  default = {
    name           = "master"
    replicas       = 3
    hyperthreading = "Enabled"
    template_id    = "dde12e2f-0fc0-4d89-b4e8-07d97ce5a966"
    instance_type  = "standard.extra-large"
    disk_size      = 120
  }
}

variable "worker_nodes" {
  description = "The worker nodes to create."
  type = list(object({
    name           = string
    replicas       = number
    hyperthreading = string
    template_id    = string
    instance_type  = string
    disk_size      = number
  }))
  default = [
    {
      name           = "apps"
      replicas       = 3
      hyperthreading = "Enabled"
      template_id    = "dde12e2f-0fc0-4d89-b4e8-07d97ce5a966"
      instance_type  = "standard.large"
      disk_size      = 120
    }
  ]
}
