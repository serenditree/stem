########################################################################################################################
# IAM roles
########################################################################################################################
resource "exoscale_iam_role" "serenditree_scaler" {
  name        = "serenditree-scaler"
  description = "Role that allows SKS autoscaling."
  editable    = false

  policy = {
    default_service_strategy = "deny"
    services = {
      compute = {
        type = "rules"
        rules = [
          {
            expression = "operation in ['get-instance', 'get-instance-pool']"
            action     = "allow"
          },
          {
            expression = "operation in ['list-sks-clusters', 'scale-sks-nodepool', 'evict-sks-nodepool-members']"
            action     = "allow"
          },
          {
            expression = "operation == 'get-quota'"
            action     = "allow"
          }
        ]
      }
    }
  }
}

resource "exoscale_iam_role" "serenditree_data" {
  name        = "serenditree-data"
  description = "Rule that allows retrieval of data from SOS."
  editable    = false

  policy = {
    default_service_strategy = "deny"
    services = {
      sos = {
        type = "rules"
        rules = [
          {
            expression = "parameters.bucket == 'serenditree-data' && operation in ['head-object', 'get-object']"
            action     = "allow"
          }
        ]
      }
    }
  }
}

resource "exoscale_iam_role" "serenditree_backup" {
  name        = "serenditree-backup"
  description = "Rule that allows backup and restore of databases."
  editable    = false

  policy = {
    default_service_strategy = "deny"
    services = {
      sos = {
        type = "rules"
        rules = [
          {
            expression = "parameters.bucket == 'serenditree-backup' && operation in ['head-object', 'get-object', 'put-object']"
            action     = "allow"
          }
        ]
      }
    }
  }
}
########################################################################################################################
# IAM keys
########################################################################################################################
resource "exoscale_iam_api_key" "serenditree_scaler" {
  name    = "serenditree-scaler"
  role_id = exoscale_iam_role.serenditree_scaler.id
}
resource "exoscale_iam_api_key" "serenditree_data" {
  name    = "serenditree-data"
  role_id = exoscale_iam_role.serenditree_data.id
}
resource "exoscale_iam_api_key" "serenditree_backup" {
  name    = "serenditree-backup"
  role_id = exoscale_iam_role.serenditree_backup.id
}

resource "local_sensitive_file" "serenditree_scaler" {
  filename        = "${var.iam}.scaler"
  content         = "${exoscale_iam_api_key.serenditree_scaler.key}:${exoscale_iam_api_key.serenditree_scaler.secret}"
  file_permission = "0600"
}
resource "local_sensitive_file" "serenditree_data" {
  filename        = "${var.iam}.data"
  content         = "${exoscale_iam_api_key.serenditree_data.key}:${exoscale_iam_api_key.serenditree_data.secret}"
  file_permission = "0600"
}
resource "local_sensitive_file" "serenditree_backup" {
  filename        = "${var.iam}.backup"
  content         = "${exoscale_iam_api_key.serenditree_backup.key}:${exoscale_iam_api_key.serenditree_backup.secret}"
  file_permission = "0600"
}
