resource "grafana_folder" "confluent_cloud" {
  count = var.create_grafana_dashboards ? 1 : 0
  title = title("${var.environment} ${var.name} Confluent Cloud")
}

resource "grafana_dashboard" "confluent_cloud" {
  count  = var.create_grafana_dashboards ? 1 : 0
  folder = grafana_folder.confluent_cloud[0].id
  config_json = templatefile(
    "${path.module}/templates/confluent-cloud.json",
    {
      datasource  = var.grafana_datasource
      clusterName = local.lc_name
    }
  )
}

resource "grafana_dashboard" "kafka_lag_exporter" {
  count  = var.create_grafana_dashboards && var.enable_metric_exporters ? 1 : 0
  folder = grafana_folder.confluent_cloud[0].id
  config_json = templatefile(
    "${path.module}/templates/kafka-lag-exporter.json",
    {
      datasource  = var.grafana_datasource
      clusterName = local.lc_name
    }
  )
}