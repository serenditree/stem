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
########################################################################################################################
# Data
########################################################################################################################
resource "aws_s3_bucket" "serenditree_data" {
  count  = var.storage_data_create ? 1 : 0
  bucket = var.storage_data

  force_destroy = false
}
########################################################################################################################
# Backup
########################################################################################################################
resource "aws_s3_bucket" "serenditree_backup" {
  count  = var.storage_backup_create ? 1 : 0
  bucket = var.storage_backup

  object_lock_enabled = true
  force_destroy       = false
}

resource "aws_s3_bucket_object_lock_configuration" "serenditree_backup_object_lock" {
  count  = var.storage_backup_create ? 1 : 0
  bucket = aws_s3_bucket.serenditree_backup[0].id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 2
    }
  }
}

resource "aws_s3_bucket_versioning" "serenditree_backup_versioning" {
  count  = var.storage_backup_create ? 1 : 0
  bucket = aws_s3_bucket.serenditree_backup[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "serenditree_backup_lifecycle" {
  count  = var.storage_backup_create ? 1 : 0
  bucket = aws_s3_bucket.serenditree_backup[0].id

  rule {
    id     = "delete-expired"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 3
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
########################################################################################################################
# Traces
########################################################################################################################
resource "aws_s3_bucket" "serenditree_traces" {
  bucket        = var.storage_traces
  force_destroy = true
}
