terraform {
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = ">= 0.61.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.3"
    }
  }
}
