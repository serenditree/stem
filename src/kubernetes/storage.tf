########################################################################################################################
# S3 Config
########################################################################################################################
provider "aws" {
  endpoints {
    s3 = "https://sos-${var.zone}.exo.io"
  }
  region                      = var.zone
  access_key                  = var.api_key
  secret_key                  = var.api_secret
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true

}
resource "aws_s3_bucket" "serenditree_traces" {
  bucket        = var.traces
  force_destroy = true
}
