terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">=1.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 1.20"
    }
  }
}

locals {
  name    = "${var.environment}-${var.name}"
  lc_name = lower(local.name)
  topic_readers = flatten([
    for name, values in var.topics :
    [for user in values.acl_readers : { topic : name, user : user }]
  ])
  readers_map = { for v in local.topic_readers : "${v.topic}/${v.user}" => v }
  readers_set = toset([
    for r in local.topic_readers : r.user
  ])
  topic_writers = flatten([
    for name, values in var.topics :
    [for user in values.acl_writers : { topic : name, user : user }]
  ])
  writers_map = { for v in local.topic_writers : "${v.topic}/${v.user}" => v }
  bootstrap_servers = [
    replace(confluent_kafka_cluster.cluster.bootstrap_endpoint, "SASL_SSL://", "")
  ]
  service_accounts = distinct(
    concat(
      [for v in local.readers_map : v.user],
      [for v in local.writers_map : v.user]
    )
  )
  rbac_users = distinct(
    concat(
      keys(var.environment_user_roles),
      keys(var.cluster_user_roles),
    )
  )
  cluster_user_roles_list = flatten([
    for user, roles in var.cluster_user_roles : [
      for role in roles : { "user" : user, "role" : role }
    ]
  ])
  environment_user_roles_list = flatten([
    for user, roles in var.environment_user_roles : [
      for role in roles : { "user" : user, "role" : role }
    ]
  ])
}

resource "random_pet" "pet" {}

resource "confluent_environment" "environment" {
  display_name = local.name
}

# Admin Service Account
resource "confluent_service_account" "admin_service_account" {
  display_name = "${local.name}-admin-service-account"
  description  = "Service Account for orders app"
}

# Admin Service Account Role Binding
resource "confluent_role_binding" "admin_sa_cluster_role_binding" {
  principal   = "User:${confluent_service_account.admin_service_account.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.cluster.rbac_crn
}

# Admin API Key
resource "confluent_api_key" "admin_api_key" {
  display_name = "${local.name}-admin-api-key"
  description  = "${local.name}-admin-api-key"
  owner {
    id          = confluent_service_account.admin_service_account.id
    api_version = confluent_service_account.admin_service_account.api_version
    kind        = confluent_service_account.admin_service_account.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.cluster.id
    api_version = confluent_kafka_cluster.cluster.api_version
    kind        = confluent_kafka_cluster.cluster.kind

    environment {
      id = confluent_environment.environment.id
    }
  }
  depends_on = [
    confluent_role_binding.admin_sa_cluster_role_binding
  ]
}

# Users Role Bindings
data "confluent_user" "rbac_users" {
  for_each = toset(local.rbac_users)
  email    = each.value
}

resource "confluent_role_binding" "cluster_role_binding" {
  for_each    = { for rb in local.cluster_user_roles_list : "${rb.user}/${rb.role}" => rb }
  principal   = "User:${data.confluent_user.rbac_users[each.value.user].id}"
  role_name   = each.value.role
  crn_pattern = confluent_kafka_cluster.cluster.rbac_crn
}

resource "confluent_role_binding" "environment_role_binding" {
  for_each    = { for rb in local.environment_user_roles_list : "${rb.user}/${rb.role}" => rb }
  principal   = "User:${data.confluent_user.rbac_users[each.value.user].id}"
  role_name   = each.value.role
  crn_pattern = confluent_environment.environment.resource_name
}

# Service Accounts
resource "confluent_service_account" "service_accounts" {
  for_each     = toset(local.service_accounts)
  display_name = "${local.lc_name}-${each.value}${var.add_service_account_suffix ? "-${random_pet.pet.id}" : ""}"
  description  = "${each.value} service account"
}

# Service Accounts API Keys
resource "confluent_api_key" "service_account_api_keys" {
  # given service_accounts = [reader, writer]
  # given service_account_key_versions = [v1, v2]
  # product is ["v1/reader", "v1/writer", "v2/reader", "v2/writer"]
  for_each     = toset([for v in setproduct(var.service_account_key_versions, local.service_accounts) : join("/", v)])
  display_name = "${local.name}-${replace(each.value,"/", "-")}-${random_pet.pet.id}-api-key"
  description  = "${local.name}-${replace(each.value,"/", "-")}-${random_pet.pet.id}-api-key"
  owner {
    id          = confluent_service_account.service_accounts[split("/",each.value)[1]].id
    api_version = confluent_service_account.service_accounts[split("/",each.value)[1]].api_version
    kind        = confluent_service_account.service_accounts[split("/",each.value)[1]].kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.cluster.id
    api_version = confluent_kafka_cluster.cluster.api_version
    kind        = confluent_kafka_cluster.cluster.kind

    environment {
      id = confluent_environment.environment.id
    }
  }
}

resource "confluent_api_key" "new_service_account_api_keys" {
  for_each     = toset(local.service_accounts)
  display_name = "${local.name}-${each.value}-${random_pet.pet.id}-api-key"
  description  = "${local.name}-${each.value}-${random_pet.pet.id}-api-key"
  owner {
    id          = confluent_service_account.service_accounts[each.value].id
    api_version = confluent_service_account.service_accounts[each.value].api_version
    kind        = confluent_service_account.service_accounts[each.value].kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.cluster.id
    api_version = confluent_kafka_cluster.cluster.api_version
    kind        = confluent_kafka_cluster.cluster.kind

    environment {
      id = confluent_environment.environment.id
    }
  }
}

# Ccloud Exporter Service Account
resource "confluent_service_account" "ccloud_exporter_service_account" {
  count        = var.enable_metric_exporters ? 1 : 0
  display_name = "${local.name}-ccloud-exporter-service-account"
  description  = "Service Account for Ccloud Exporter"
}

# Ccloud Exporter Service Account Role Binding
resource "confluent_role_binding" "ccloud_exporter_sa_cluster_role_binding" {
  count       = var.enable_metric_exporters ? 1 : 0
  principal   = "User:${confluent_service_account.ccloud_exporter_service_account[count.index].id}"
  role_name   = "MetricsViewer"
  crn_pattern = confluent_kafka_cluster.cluster.rbac_crn
}

# Ccloud Exporter API Key
resource "confluent_api_key" "ccloud_exporter_api_key" {
  count = var.enable_metric_exporters ? 1 : 0

  display_name = "${local.name} ccloud exporter api key"
  description  = "${local.name} ccloud exporter api key"
  owner {
    id          = confluent_service_account.ccloud_exporter_service_account[count.index].id
    api_version = confluent_service_account.ccloud_exporter_service_account[count.index].api_version
    kind        = confluent_service_account.ccloud_exporter_service_account[count.index].kind
  }

  depends_on = [
    confluent_role_binding.ccloud_exporter_sa_cluster_role_binding
  ]
}

# Cluster
resource "confluent_kafka_cluster" "cluster" {
  display_name = local.name
  availability = var.availability
  cloud        = var.service_provider
  region       = var.gcp_region

  dynamic "basic" {
    for_each = lower(var.cluster_tier) == "basic" ? [1] : []
    content {}
  }

  dynamic "standard" {
    for_each = lower(var.cluster_tier) == "standard" ? [1] : []
    content {}
  }

  dynamic "enterprise" {
    for_each = lower(var.cluster_tier) == "enterprise" ? [1] : []
    content {}
  }

  dynamic "dedicated" {
    for_each = lower(var.cluster_tier) == "dedicated" ? [1] : []
    content {
      cku = var.cku
    }
  }

  environment {
    id = confluent_environment.environment.id
  }
}

# Topics
resource "confluent_kafka_topic" "topics" {
  for_each = var.topics
  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }
  topic_name       = each.key
  partitions_count = each.value.partitions
  rest_endpoint    = confluent_kafka_cluster.cluster.rest_endpoint
  config           = try(each.value.config, {})
  credentials {
    key    = confluent_api_key.admin_api_key.id
    secret = confluent_api_key.admin_api_key.secret
  }
}

# Topic Readers ACL
resource "confluent_kafka_acl" "readers" {
  for_each = local.readers_map

  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }
  resource_type = "TOPIC"
  resource_name = each.value.topic
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.service_accounts[each.value.user].id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.admin_api_key.id
    secret = confluent_api_key.admin_api_key.secret
  }
}

# Topic Writers ACL
resource "confluent_kafka_acl" "writers" {
  for_each = local.writers_map

  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }
  resource_type = "TOPIC"
  resource_name = each.value.topic
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.service_accounts[each.value.user].id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.admin_api_key.id
    secret = confluent_api_key.admin_api_key.secret
  }
}

# Group Readers ACL
resource "confluent_kafka_acl" "group_readers" {
  for_each = local.readers_set

  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }
  resource_type = "GROUP"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.service_accounts[each.value].id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.admin_api_key.id
    secret = confluent_api_key.admin_api_key.secret
  }
}
