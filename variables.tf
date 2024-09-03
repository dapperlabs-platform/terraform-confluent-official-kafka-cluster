variable "name" {
  description = "Kafka cluster identifier. Will be prepended by the environment value in Confluent cloud"
  type        = string
}

variable "environment" {
  description = "Application environment that uses the cluster"
  type        = string
}

variable "gcp_region" {
  description = "GCP region in which to deploy the cluster. See https://docs.confluent.io/cloud/current/clusters/regions.html"
  type        = string
}

variable "topics" {
  description = <<EOF
  Kafka topic definitions.
  Object map keyed by topic name with topic configuration values as well as reader and writer ACL lists.
  Values provided to the ACL lists will become service accounts with { key, secret } objects output by service_account_credentials
  EOF
  type = map(
    object({
      replication_factor = number
      partitions         = number
      config             = map(any)
      acl_readers        = list(string)
      acl_writers        = list(string)
    })
  )
}

variable "environment_user_roles" {
  description = "Map of users with list of roles for Environment-level access"
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([for role in flatten(values(var.environment_user_roles)) : contains([
      "EnvironmentAdmin", "Operator", "MetricsViewer"
    ], role)])
    error_message = "Bad environment role (should be one of \"EnvironmentAdmin\", \"Operator\" or \"MetricsViewer\")."
  }
}

variable "cluster_user_roles" {
  description = "Map of users with list of roles for Cluster-level access"
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([for role in flatten(values(var.cluster_user_roles)) : contains([
      "CloudClusterAdmin", "Operator", "MetricsViewer"
    ], role)])
    error_message = "Bad cluster role (should be one of \"CloudClusterAdmin\", \"Operator\" or \"MetricsViewer\")."
  }
}

variable "add_service_account_suffix" {
  description = "Add pet name suffix to service account names to avoid collision"
  type        = bool
  default     = false
}

variable "service_provider" {
  description = "Confluent cloud service provider. AWS, GCP, Azure"
  type        = string
  default     = "GCP"
}

variable "availability" {
  description = "Cluster availability. SINGLE_ZONE or MULTI_ZONE"
  type        = string
  default     = "MULTI_ZONE"
}

variable "cku" {
  description = "Number of CKUs"
  type        = number
  default     = 2
}

variable "cluster_tier" {
  type        = string
  description = "type of cluster to provision: basic, standard, dedicated or enterprise"
}

variable "enable_metric_exporters" {
  description = "Whether to deploy kafka-lag-exporter and ccloud-exporter in a kubernetes cluster"
  type        = bool
  default     = false
}

variable "metric_exporters_namespace" {
  description = "Namespace to deploy exporters to"
  type        = string
  default     = "sre"
}

variable "kafka_lag_exporter_annotations" {
  description = "Lag exporter annotations"
  type        = map(string)
  default     = {}
}

variable "ccloud_exporter_annotations" {
  description = "CCloud exporter annotations"
  type        = map(string)
  default     = {}
}

variable "kafka_lag_exporter_image_version" {
  description = "See https://github.com/seglo/kafka-lag-exporter/releases"
  type        = string
  default     = "0.7.1"
}

variable "kafka_lag_exporter_log_level" {
  description = "Lag exporter log level"
  type        = string
  default     = "INFO"
}

variable "kafka_lag_exporter_container_resources" {
  description = "Container resource limit configuration"
  type        = map(map(string))
  default = {
    requests = {
      cpu    = "250m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "500m"
      memory = "2Gi"
    }
  }
}

variable "create_grafana_dashboards" {
  description = "Whether to create grafana dashboards with default metric exporter panels"
  type        = bool
  default     = false
}

variable "grafana_datasource" {
  description = "Name of Grafana data source where Kafka metrics are stored"
  type        = string
  default     = null
}

variable "exporters_node_selector" {
  description = "K8S Deployment node selector for metric exporters"
  type        = map(string)
  default     = null
}

variable "ccloud_exporter_image_version" {
  description = "Exporter Image Version"
  type        = string
  default     = "latest"
}

variable "ccloud_exporter_container_resources" {
  description = "Container resource limit configuration"
  type        = map(map(string))
  default = {
    requests = {
      cpu    = "250m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "500m"
      memory = "2Gi"
    }
  }
}

variable "service_account_key_versions" {
  description = "When creating multiple service account keys, group them by the versions provided in this variable"
  type        = list(string)
  default     = ["default"]
}
