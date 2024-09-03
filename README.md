# Confluent Kafka Cluster(Official)

https://www.confluent.io/confluent-cloud/

https://registry.terraform.io/providers/confluentinc/confluent/latest/docs

## What does this do?

Creates a Confluent Cloud Kafka cluster, topics, service accounts, role bindings

## How to use this module?

```hcl
module "confluent-kafka-cluster" {
  source                            = "github.com/dapperlabs-platform/terraform-confluent-official-kafka-cluster?ref=tag"
  environment              = "DEMO"
  gcp_region               = var.default_region
  name                     = "cruise"

  # OPTIONAL: Only needed when creating dedicated cluster, if not provided defaults to 2
  cku                      = 2

  # you must provide one of: basic, standard, enterprise, or dedicated
  cluster_tier             = "DEDICATED"

  # Note Basic Cluster cannot have MULTI_ZONE availability just SINGLE_ZONE
  availability             = "MULTI_ZONE"

  kafka_lag_exporter_image_version = "0.7.1"
  ccloud_exporter_image_version = "0.7.1"
  
  topics = {
    "topic-1" = {
      replication_factor = 3
      partitions         = 1
      config = {
        "cleanup.policy" = "delete"
      }
      acl_readers = ["user1"]
      acl_writers = ["user2"]
    }
  }
}
```

## Resources created

- 1 Confluent Cloud environment
- 1 Kafka cluster
- 1 Service account for each distinct entry in `acl_readers` and `acl_writers` variables
- Topics

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_confluent"></a> [confluent](#requirement\_confluent) | >=1.0.0 |
| <a name="requirement_grafana"></a> [grafana](#requirement\_grafana) | ~> 1.20 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_confluent"></a> [confluent](#provider\_confluent) | >=1.0.0 |
| <a name="provider_grafana"></a> [grafana](#provider\_grafana) | ~> 1.20 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [confluent_api_key.admin_api_key](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/api_key) | resource |
| [confluent_api_key.ccloud_exporter_api_key](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/api_key) | resource |
| [confluent_api_key.kafka_lag_exporter_api_key](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/api_key) | resource |
| [confluent_api_key.service_account_api_keys](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/api_key) | resource |
| [confluent_environment.environment](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/environment) | resource |
| [confluent_kafka_acl.group_readers](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/kafka_acl) | resource |
| [confluent_kafka_acl.kafka_lag_exporter_describe_consumer_group](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/kafka_acl) | resource |
| [confluent_kafka_acl.kafka_lag_exporter_describe_topic](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/kafka_acl) | resource |
| [confluent_kafka_acl.kafka_lag_exporter_read_topic](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/kafka_acl) | resource |
| [confluent_kafka_acl.readers](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/kafka_acl) | resource |
| [confluent_kafka_acl.writers](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/kafka_acl) | resource |
| [confluent_kafka_cluster.cluster](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/kafka_cluster) | resource |
| [confluent_kafka_topic.topics](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/kafka_topic) | resource |
| [confluent_role_binding.admin_sa_cluster_role_binding](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/role_binding) | resource |
| [confluent_role_binding.ccloud_exporter_sa_cluster_role_binding](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/role_binding) | resource |
| [confluent_role_binding.cluster_role_binding](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/role_binding) | resource |
| [confluent_role_binding.environment_role_binding](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/role_binding) | resource |
| [confluent_role_binding.kafka_lag_exporter_cluster_role_binding](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/role_binding) | resource |
| [confluent_service_account.admin_service_account](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/service_account) | resource |
| [confluent_service_account.ccloud_exporter_service_account](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/service_account) | resource |
| [confluent_service_account.kafka_lag_exporter](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/service_account) | resource |
| [confluent_service_account.service_accounts](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/service_account) | resource |
| [grafana_dashboard.ccloud_exporter](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/dashboard) | resource |
| [grafana_dashboard.kafka_lag_exporter](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/dashboard) | resource |
| [grafana_folder.confluent_cloud](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/folder) | resource |
| [kubernetes_deployment.ccloud_exporter_deployment](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_deployment.lag_exporter_deployment](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_secret.ccloud_exporter_config](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.ccloud_exporter_config_file](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.lag_exporter_config](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.ccloud_exporter_service_account](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_service_account.lag_exporter_service_account](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [random_pet.pet](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [confluent_user.rbac_users](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/data-sources/user) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_add_service_account_suffix"></a> [add\_service\_account\_suffix](#input\_add\_service\_account\_suffix) | Add pet name suffix to service account names to avoid collision | `bool` | `false` | no |
| <a name="input_availability"></a> [availability](#input\_availability) | Cluster availability. SINGLE\_ZONE or MULTI\_ZONE | `string` | `"MULTI_ZONE"` | no |
| <a name="input_ccloud_exporter_annotations"></a> [ccloud\_exporter\_annotations](#input\_ccloud\_exporter\_annotations) | CCloud exporter annotations | `map(string)` | `{}` | no |
| <a name="input_ccloud_exporter_container_resources"></a> [ccloud\_exporter\_container\_resources](#input\_ccloud\_exporter\_container\_resources) | Container resource limit configuration | `map(map(string))` | <pre>{<br>  "limits": {<br>    "cpu": "500m",<br>    "memory": "2Gi"<br>  },<br>  "requests": {<br>    "cpu": "250m",<br>    "memory": "1Gi"<br>  }<br>}</pre> | no |
| <a name="input_ccloud_exporter_image_version"></a> [ccloud\_exporter\_image\_version](#input\_ccloud\_exporter\_image\_version) | Exporter Image Version | `string` | `"latest"` | no |
| <a name="input_cku"></a> [cku](#input\_cku) | Number of CKUs | `number` | `2` | no |
| <a name="input_cluster_tier"></a> [cluster\_tier](#input\_cluster\_tier) | type of cluster to provision: basic, standard, enterprise, or dedicated | `string` | n/a | yes |
| <a name="input_cluster_user_roles"></a> [cluster\_user\_roles](#input\_cluster\_user\_roles) | Map of users with list of roles for Cluster-level access | `map(list(string))` | `{}` | no |
| <a name="input_create_grafana_dashboards"></a> [create\_grafana\_dashboards](#input\_create\_grafana\_dashboards) | Whether to create grafana dashboards with default metric exporter panels | `bool` | `false` | no |
| <a name="input_enable_metric_exporters"></a> [enable\_metric\_exporters](#input\_enable\_metric\_exporters) | Whether to deploy kafka-lag-exporter and ccloud-exporter in a kubernetes cluster | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Application environment that uses the cluster | `string` | n/a | yes |
| <a name="input_environment_user_roles"></a> [environment\_user\_roles](#input\_environment\_user\_roles) | Map of users with list of roles for Environment-level access | `map(list(string))` | `{}` | no |
| <a name="input_exporters_node_selector"></a> [exporters\_node\_selector](#input\_exporters\_node\_selector) | K8S Deployment node selector for metric exporters | `map(string)` | `null` | no |
| <a name="input_gcp_region"></a> [gcp\_region](#input\_gcp\_region) | GCP region in which to deploy the cluster. See https://docs.confluent.io/cloud/current/clusters/regions.html | `string` | n/a | yes |
| <a name="input_grafana_datasource"></a> [grafana\_datasource](#input\_grafana\_datasource) | Name of Grafana data source where Kafka metrics are stored | `string` | `null` | no |
| <a name="input_kafka_lag_exporter_annotations"></a> [kafka\_lag\_exporter\_annotations](#input\_kafka\_lag\_exporter\_annotations) | Lag exporter annotations | `map(string)` | `{}` | no |
| <a name="input_kafka_lag_exporter_container_resources"></a> [kafka\_lag\_exporter\_container\_resources](#input\_kafka\_lag\_exporter\_container\_resources) | Container resource limit configuration | `map(map(string))` | <pre>{<br>  "limits": {<br>    "cpu": "500m",<br>    "memory": "2Gi"<br>  },<br>  "requests": {<br>    "cpu": "250m",<br>    "memory": "1Gi"<br>  }<br>}</pre> | no |
| <a name="input_kafka_lag_exporter_image_version"></a> [kafka\_lag\_exporter\_image\_version](#input\_kafka\_lag\_exporter\_image\_version) | See https://github.com/seglo/kafka-lag-exporter/releases | `string` | `"0.7.1"` | no |
| <a name="input_kafka_lag_exporter_log_level"></a> [kafka\_lag\_exporter\_log\_level](#input\_kafka\_lag\_exporter\_log\_level) | Lag exporter log level | `string` | `"INFO"` | no |
| <a name="input_metric_exporters_namespace"></a> [metric\_exporters\_namespace](#input\_metric\_exporters\_namespace) | Namespace to deploy exporters to | `string` | `"sre"` | no |
| <a name="input_name"></a> [name](#input\_name) | Kafka cluster identifier. Will be prepended by the environment value in Confluent cloud | `string` | n/a | yes |
| <a name="input_service_provider"></a> [service\_provider](#input\_service\_provider) | Confluent cloud service provider. AWS, GCP, Azure | `string` | `"GCP"` | no |
| <a name="input_topics"></a> [topics](#input\_topics) | Kafka topic definitions.<br>  Object map keyed by topic name with topic configuration values as well as reader and writer ACL lists.<br>  Values provided to the ACL lists will become service accounts with { key, secret } objects output by service\_account\_credentials | <pre>map(<br>    object({<br>      replication_factor = number<br>      partitions         = number<br>      config             = map(any)<br>      acl_readers        = list(string)<br>      acl_writers        = list(string)<br>    })<br>  )</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_api_key"></a> [admin\_api\_key](#output\_admin\_api\_key) | Admin user api key and secret |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | The confluent kafka cluster id |
| <a name="output_confluent_environment"></a> [confluent\_environment](#output\_confluent\_environment) | The confluent environment id |
| <a name="output_kafka_url"></a> [kafka\_url](#output\_kafka\_url) | URL to connect your Kafka clients to |
| <a name="output_service_account_credentials"></a> [service\_account\_credentials](#output\_service\_account\_credentials) | Map containing service account credentials.<br>  Keys are service account names provided to topics as readers and writers.<br>  Values are objects with key and secret values. |