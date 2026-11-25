# Confluent Cloud platform: environment, Standard cluster, Flink pool, service
# account and API keys. Confluent resources have no cloud tags, so the project name
# and teardown date go in the display names and descriptions.

data "confluent_organization" "main" {}

resource "confluent_environment" "demo" {
  display_name = "${var.project}-env"

  stream_governance {
    package = "ESSENTIALS"
  }
}

resource "confluent_kafka_cluster" "demo" {
  display_name = "${var.project}-cluster"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = var.aws_region

  standard {}

  environment {
    id = confluent_environment.demo.id
  }
}

data "confluent_schema_registry_cluster" "demo" {
  environment {
    id = confluent_environment.demo.id
  }

  depends_on = [confluent_kafka_cluster.demo]
}

data "confluent_flink_region" "demo" {
  cloud  = "AWS"
  region = var.aws_region
}

resource "confluent_flink_compute_pool" "demo" {
  display_name = "${var.project}-pool"
  cloud        = "AWS"
  region       = var.aws_region
  max_cfu      = var.flink_max_cfu

  environment {
    id = confluent_environment.demo.id
  }
}

resource "confluent_service_account" "app" {
  display_name = "${var.project}-app"
  description  = "Deal hunter demo (keep until ${var.keep_until})"
}

resource "confluent_role_binding" "app_env_admin" {
  principal   = "User:${confluent_service_account.app.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.demo.resource_name
}

resource "confluent_api_key" "kafka" {
  display_name = "${var.project}-kafka"
  description  = "Kafka API key for the demo clients"

  owner {
    id          = confluent_service_account.app.id
    api_version = confluent_service_account.app.api_version
    kind        = confluent_service_account.app.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.demo.id
    api_version = confluent_kafka_cluster.demo.api_version
    kind        = confluent_kafka_cluster.demo.kind

    environment {
      id = confluent_environment.demo.id
    }
  }

  depends_on = [confluent_role_binding.app_env_admin]
}

resource "confluent_api_key" "schema_registry" {
  display_name = "${var.project}-sr"
  description  = "Schema Registry API key for the demo clients"

  owner {
    id          = confluent_service_account.app.id
    api_version = confluent_service_account.app.api_version
    kind        = confluent_service_account.app.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.demo.id
    api_version = data.confluent_schema_registry_cluster.demo.api_version
    kind        = data.confluent_schema_registry_cluster.demo.kind

    environment {
      id = confluent_environment.demo.id
    }
  }

  depends_on = [confluent_role_binding.app_env_admin]
}

resource "confluent_api_key" "flink" {
  display_name = "${var.project}-flink"
  description  = "Flink API key used by Terraform to submit statements"

  owner {
    id          = confluent_service_account.app.id
    api_version = confluent_service_account.app.api_version
    kind        = confluent_service_account.app.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.demo.id
    api_version = data.confluent_flink_region.demo.api_version
    kind        = data.confluent_flink_region.demo.kind

    environment {
      id = confluent_environment.demo.id
    }
  }

  depends_on = [confluent_role_binding.app_env_admin]
}
