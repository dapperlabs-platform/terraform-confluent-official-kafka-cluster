output "service_account_credentials" {
  description = <<EOF
  Map containing service account credentials.
  Keys are service account names provided to topics as readers and writers.
  Values are objects with key and secret values.
  EOF
  value       = { for name, v in confluent_api_key.service_account_api_keys : name => { key : v.id, secret : v.secret } }
  sensitive   = true
}

output "new_service_account_credentials" {
  description = <<EOF
  New service account credentials
  EOF
  value       = { for name, v in confluent_api_key.new_service_account_api_keys : name => { key : v.id, secret : v.secret } }
  sensitive   = true
}

output "kafka_url" {
  description = "URL to connect your Kafka clients to"
  value       = local.bootstrap_servers
}

output "admin_api_key" {
  description = "Admin user api key and secret"
  value       = confluent_api_key.admin_api_key
  sensitive   = true
}


output "cluster_id" {
  description = "The confluent kafka cluster id"
  value       = confluent_kafka_cluster.cluster.id
  sensitive   = true
}

output "confluent_environment" {
  description = "The confluent environment id"
  value       = confluent_environment.environment.id
  sensitive   = true
}