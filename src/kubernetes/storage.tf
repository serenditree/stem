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
  count  = var.storage_data == "" ? 0 : 1
  bucket = var.storage_data

  force_destroy = false
}
########################################################################################################################
# Backup
########################################################################################################################
locals {
  backup_replicas = [for id, bucket in var.storage_backup : "${bucket}-replica"]
  backup_buckets  = toset(concat(var.storage_backup, local.backup_replicas))
}

resource "aws_s3_bucket" "serenditree_backup" {
  for_each = local.backup_buckets
  bucket   = each.key

  object_lock_enabled = true
  force_destroy       = false
}

resource "aws_s3_bucket_object_lock_configuration" "serenditree_backup_object_lock" {
  for_each = local.backup_buckets
  bucket   = aws_s3_bucket.serenditree_backup[each.key].id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 3
    }
  }
}

resource "aws_s3_bucket_versioning" "serenditree_backup_versioning" {
  for_each = local.backup_buckets
  bucket   = aws_s3_bucket.serenditree_backup[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "serenditree_backup_lifecycle" {
  for_each = local.backup_buckets
  bucket   = aws_s3_bucket.serenditree_backup[each.key].id

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
