terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">=1.0.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = ">= 1.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2"
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
}

resource "random_pet" "pet" {}

# Cloud Environment
data "confluent_environment" "environment" {
  id = "env-op92o"
}

#resource "confluent_environment" "environment" {
#  display_name = local.name
#}

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
      #TODO id = confluent_environment.environment.id
      id = data.confluent_environment.environment.id
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
resource "confluent_api_key" "service_account_api_key" {
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
      #TODO id = confluent_environment.environment.id
      id = data.confluent_environment.environment.id
    }
  }
  depends_on = [
    confluent_role_binding.service_accounts_cluster_role_binding
  ]
}

# Confluent Cloud Exporter Service Account
resource "confluent_service_account" "ccloud_exporter_service_account" {
  count = var.enable_metric_exporters ? 1 : 0

  display_name = "${local.name}-ccloud-exporter-service-account"
  description  = "${local.name}-ccloud-exporter-service-account"
}

# Confluent Cloud Exporter Service Account Role Binding
resource "confluent_role_binding" "ccloud_exporter_role_binding" {
  count = var.enable_metric_exporters ? 1 : 0

  principal   = "User:${confluent_service_account.ccloud_exporter_service_account[0].id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.cluster.rbac_crn

  depends_on = [
    confluent_service_account.ccloud_exporter_service_account
  ]
}

# Confluent Cloud Exporter API Key
resource "confluent_api_key" "ccloud_exporter_api_key" {
  count = var.enable_metric_exporters ? 1 : 0

  display_name = "${local.name}-ccloud-exporter-api-key"
  description  = "${local.name}-ccloud-exporter-api-key"
  owner {
    id          = confluent_service_account.ccloud_exporter_service_account[0].id
    api_version = confluent_service_account.ccloud_exporter_service_account[0].api_version
    kind        = confluent_service_account.ccloud_exporter_service_account[0].kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.cluster.id
    api_version = confluent_kafka_cluster.cluster.api_version
    kind        = confluent_kafka_cluster.cluster.kind

    environment {
      #TODO id = confluent_environment.environment.id
      id = data.confluent_environment.environment.id
    }
  }
  depends_on = [
    confluent_role_binding.ccloud_exporter_role_binding
  ]
}

# Kafka Lag Exporter Service Account
resource "confluent_service_account" "kafka_lag_exporter_service_account" {
  count = var.enable_metric_exporters ? 1 : 0

  display_name = "${local.name}-kafka-lag-exporter-service-account"
  description  = "${local.name}-kafka-lag-exporter-service-account"
}

# Kafka Lag Exporter Service Account Role Binding
resource "confluent_role_binding" "kafka_lag_exporter_role_binding" {
  count = var.enable_metric_exporters ? 1 : 0

  principal   = "User:${confluent_service_account.kafka_lag_exporter_service_account[0].id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.cluster.rbac_crn

  depends_on = [
    confluent_service_account.kafka_lag_exporter_service_account
  ]
}

# Kafka Lag Exporter API Key
resource "confluent_api_key" "kafka_lag_exporter_api_key" {
  count = var.enable_metric_exporters ? 1 : 0

  display_name = "${local.name}-kafka-lag-exporter-api-key"
  description  = "${local.name}-kafka-lag-exporter-api-key"
  owner {
    id          = confluent_service_account.kafka_lag_exporter_service_account[0].id
    api_version = confluent_service_account.kafka_lag_exporter_service_account[0].api_version
    kind        = confluent_service_account.kafka_lag_exporter_service_account[0].kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.cluster.id
    api_version = confluent_kafka_cluster.cluster.api_version
    kind        = confluent_kafka_cluster.cluster.kind

    environment {
      #TODO id = confluent_environment.environment.id
      id = data.confluent_environment.environment.id
    }
  }
  depends_on = [
    confluent_role_binding.kafka_lag_exporter_role_binding
  ]
}

# Kafka Lag Exporter Read Topic ACL
resource "confluent_kafka_acl" "kafka_lag_exporter_read_topic" {
  count = var.enable_metric_exporters ? 1 : 0

  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }
  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.kafka_lag_exporter_service_account[0].id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.kafka_lag_exporter_api_key[0].id
    secret = confluent_api_key.kafka_lag_exporter_api_key[0].secret
  }
}

# Kafka Lag Exporter Describe Topic ACL
resource "confluent_kafka_acl" "kafka_lag_exporter_describe_topic" {
  count = var.enable_metric_exporters ? 1 : 0

  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }
  resource_type = "TOPIC"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.kafka_lag_exporter_service_account[0].id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.kafka_lag_exporter_api_key[0].id
    secret = confluent_api_key.kafka_lag_exporter_api_key[0].secret
  }
}

# Kafka Lag Exporter Describe Group ACL
resource "confluent_kafka_acl" "kafka_lag_exporter_describe_group" {
  count = var.enable_metric_exporters ? 1 : 0

  kafka_cluster {
    id = confluent_kafka_cluster.cluster.id
  }
  resource_type = "GROUP"
  resource_name = "*"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.kafka_lag_exporter_service_account[0].id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.kafka_lag_exporter_api_key[0].id
    secret = confluent_api_key.kafka_lag_exporter_api_key[0].secret
  }
}

# Cluster
resource "confluent_kafka_cluster" "cluster" {
  display_name = local.name
  availability = var.availability
  cloud        = var.service_provider
  region       = var.gcp_region
  dedicated {
    cku = var.cku
  }

  environment {
    #   #TODO  id = confluent_environment.environment.id
    id = data.confluent_environment.environment.id
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
    key    = confluent_api_key.service_account_api_key[each.value.user].id
    secret = confluent_api_key.service_account_api_key[each.value.user].secret
  }
}

# Topic Writers ACL
resource "confluent_kafka_acl" "writers" {
  for_each = local.readers_map

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
    key    = confluent_api_key.service_account_api_key[each.value.user].id
    secret = confluent_api_key.service_account_api_key[each.value.user].secret
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
    key    = confluent_api_key.service_account_api_key[each.value].id
    secret = confluent_api_key.service_account_api_key[each.value].secret
  }
}
