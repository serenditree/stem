terraform {
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.65"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    bucket       = "serenditree-state"
    key          = "data/serenditree.tfstate"
    region       = "at-vie-1"
    use_lockfile = true

    endpoints = {
      s3 = "https://sos-at-vie-1.exo.io"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}
