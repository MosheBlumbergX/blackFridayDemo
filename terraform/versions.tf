terraform {
  required_version = ">= 1.9.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.95"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# Confluent credentials come from the environment, never from files:
#   CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET (Cloud resource management key)
provider "confluent" {}

# Every AWS resource gets the mandatory tags through default_tags. The Lambda log
# group, which default_tags would not reach on its own, is declared explicitly in
# mcp.tf.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}
