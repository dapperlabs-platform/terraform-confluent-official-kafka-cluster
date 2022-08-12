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
      version = ">= 1.14.0"
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
      [for v in local.writers_map : v.user],
      keys(var.extra_accounts)
    )
  )
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

# Service Accounts
resource "confluent_service_account" "service_accounts" {
  for_each     = toset(local.service_accounts)
  display_name = "${local.lc_name}-${each.value}${var.add_service_account_suffix ? "-${random_pet.pet.id}" : ""}"
  description  = "${each.value} service account"
}

# Service Account Role Bindings
resource "confluent_role_binding" "service_accounts_cluster_role_binding" {
  for_each    = toset(local.service_accounts)
  principal   = "User:${confluent_service_account.service_accounts[each.value].id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.cluster.rbac_crn
}

# Service Accounts API Keys
resource "confluent_api_key" "service_account_api_keys" {
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
  depends_on = [
    confluent_role_binding.service_accounts_cluster_role_binding
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
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.service_accounts[each.value.user].id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.service_account_api_keys[each.value.user].id
    secret = confluent_api_key.service_account_api_keys[each.value.user].secret
  }
}

# Topic Writers ACL
resource "confluent_kafka_acl" "writers" {
  for_each = local.writers_map

  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }
  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.service_accounts[each.value.user].id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.service_account_api_keys[each.value.user].id
    secret = confluent_api_key.service_account_api_keys[each.value.user].secret
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
    key    = confluent_api_key.service_account_api_keys[each.value].id
    secret = confluent_api_key.service_account_api_keys[each.value].secret
  }
}
/*
 New realisation of ACL
*/
//Account Readers ACL
resource "confluent_kafka_acl" "extra_accounts_readers" {
  for_each = var.extra_accounts

  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }

  resource_type = "TOPIC"
  resource_name = each.value.acl_read
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.service_accounts[each.key].id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.service_account_api_keys[each.value].id
    secret = confluent_api_key.service_account_api_keys[each.value].secret
  }
}

//Account Writers ACL
resource "confluent_kafka_acl" "extra_accounts_writers" {
  for_each = var.extra_accounts

  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }

  resource_type = "TOPIC"
  resource_name = each.value.acl_write
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.service_accounts[each.key].id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.service_account_api_keys[each.value].id
    secret = confluent_api_key.service_account_api_keys[each.value].secret
  }
}

# Group Readers ACL
resource "confluent_kafka_acl" "extra_accounts_group_readers" {
  for_each = var.extra_accounts

  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }
  resource_type = "GROUP"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.service_accounts[each.key].id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.service_account_api_keys[each.value].id
    secret = confluent_api_key.service_account_api_keys[each.value].secret
  }
}

