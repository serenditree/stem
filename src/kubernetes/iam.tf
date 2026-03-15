########################################################################################################################
# IAM roles
########################################################################################################################
locals {
  backup_roles = toset(["user", "seed"])
}

resource "exoscale_iam_role" "serenditree_backup" {
  for_each    = local.backup_roles
  name        = "serenditree-backup-${each.key}"
  description = "Role that allows backup and restore of databases to and from a single SOS bucket."
  editable    = false

  policy = {
    default_service_strategy = "deny"
    services = {
      sos = {
        type = "rules"
        rules = [
          {
            expression = "parameters.bucket != 'serenditree-backup-${each.key}'"
            action     = "deny"
          },
          {
            expression = "operation.matches('^[^-]+-object.*')"
            action     = "allow"
          }
        ]
      }
    }
  }
}

resource "exoscale_iam_role" "serenditree_data" {
  name        = "serenditree-data"
  description = "Role that allows retrieval of data from a single SOS bucket."
  editable    = false

  policy = {
    default_service_strategy = "deny"
    services = {
      sos = {
        type = "rules"
        rules = [
          {
            expression = "parameters.bucket != 'serenditree-data'"
            action     = "deny"
          },
          {
            expression = "operation in ['head-object', 'get-object']"
            action     = "allow"
          }
        ]
      }
    }
  }
}

resource "exoscale_iam_role" "serenditree_dns" {
  count       = var.issuer_dns ? 1 : 0
  name        = "serenditree-dns"
  description = "Role for the DNS challenge."
  editable    = false

  policy = {
    default_service_strategy = "deny"
    services = {
      dns = {
        type = "rules"
        rules = [
          {
            expression = "resources.dns_domain.unicode_name != \"${var.host}\"",
            action     = "deny"
          },
          {
            expression = "parameters.has('type') && parameters.type != 'TXT'",
            action     = "deny"
          },
          {
            expression = "resources.has('dns_domain_record') && resources.dns_domain_record.has('type') && resources.dns_domain_record.type != 'TXT'",
            action     = "deny"
          },
          {
            expression = "operation in ['list-dns-domains', 'list-dns-domain-records', 'get-dns-domain-record', 'create-dns-domain-record', 'delete-dns-domain-record']",
            action     = "allow"
          }
        ]
      }
    }
  }
}

resource "exoscale_iam_role" "serenditree_traces" {
  name        = "serenditree-traces"
  description = "Role that allows RW access to a single SOS bucket for telemetry signals."
  editable    = false

  policy = {
    default_service_strategy = "deny"
    services = {
      sos = {
        type = "rules"
        rules = [
          {
            expression = "parameters.bucket != 'serenditree-traces'"
            action     = "deny"
          },
          {
            expression = "operation.matches('^(list|head|get|put)-objects?$')"
            action     = "allow"
          }
        ]
      }
    }
  }
}

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
########################################################################################################################
# IAM keys
########################################################################################################################
resource "exoscale_iam_api_key" "serenditree_backup" {
  for_each = local.backup_roles
  name     = "serenditree-backup-${each.key}"
  role_id  = exoscale_iam_role.serenditree_backup[each.key].id
}
resource "local_sensitive_file" "serenditree_backup" {
  for_each        = local.backup_roles
  filename        = "backup-${each.key}.iam"
  content         = "${exoscale_iam_api_key.serenditree_backup[each.key].key}:${exoscale_iam_api_key.serenditree_backup[each.key].secret}"
  file_permission = "0600"
}

resource "exoscale_iam_api_key" "serenditree_data" {
  name    = "serenditree-data"
  role_id = exoscale_iam_role.serenditree_data.id
}
resource "local_sensitive_file" "serenditree_data" {
  filename        = "data.iam"
  content         = "${exoscale_iam_api_key.serenditree_data.key}:${exoscale_iam_api_key.serenditree_data.secret}"
  file_permission = "0600"
}

resource "exoscale_iam_api_key" "serenditree_dns" {
  count   = var.issuer_dns ? 1 : 0
  name    = "serenditree-dns"
  role_id = exoscale_iam_role.serenditree_dns[0].id
}
resource "local_sensitive_file" "serenditree_dns" {
  count           = var.issuer_dns ? 1 : 0
  filename        = "dns.iam"
  content         = "${exoscale_iam_api_key.serenditree_dns[0].key}:${exoscale_iam_api_key.serenditree_dns[0].secret}"
  file_permission = "0600"
}

resource "exoscale_iam_api_key" "serenditree_traces" {
  name    = "serenditree-traces"
  role_id = exoscale_iam_role.serenditree_traces.id
}
resource "local_sensitive_file" "serenditree_traces" {
  filename        = "traces.iam"
  content         = "${exoscale_iam_api_key.serenditree_traces.key}:${exoscale_iam_api_key.serenditree_traces.secret}"
  file_permission = "0600"
}

resource "exoscale_iam_api_key" "serenditree_scaler" {
  name    = "serenditree-scaler"
  role_id = exoscale_iam_role.serenditree_scaler.id
}
resource "local_sensitive_file" "serenditree_scaler" {
  filename        = "scaler.iam"
  content         = "${exoscale_iam_api_key.serenditree_scaler.key}:${exoscale_iam_api_key.serenditree_scaler.secret}"
  file_permission = "0600"
}
