########################################################################################################################
# IAM role
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
            expression = "operation == 'get-instance'"
            action     = "allow"
          },
          {
            expression = "operation == 'get-instance-pool'"
            action     = "allow"
          },
          {
            expression = "operation == 'list-sks-clusters'"
            action     = "allow"
          },
          {
            expression = "operation == 'scale-sks-nodepool'"
            action     = "allow"
          },
          {
            expression = "operation == 'evict-sks-nodepool-members'"
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
########################################################################################################################
# IAM key
########################################################################################################################
resource "exoscale_iam_api_key" "serenditree_scaler" {
  name    = "serenditree-scaler"
  role_id = exoscale_iam_role.serenditree_scaler.id
}

resource "local_sensitive_file" "serenditree_scaler" {
  filename        = var.iam
  content         = "${exoscale_iam_api_key.serenditree_scaler.key}:${exoscale_iam_api_key.serenditree_scaler.secret}"
  file_permission = "0600"
}
