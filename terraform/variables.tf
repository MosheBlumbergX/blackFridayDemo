variable "aws_region" {
  description = "AWS region for Confluent Cloud, Lambda and SES. UK default: London."
  type        = string
  default     = "eu-west-2"
}

variable "project" {
  description = "Short project name. Used in resource names and the cflt_managed_id tag."
  type        = string
  default     = "blackfridaydemo"
}

variable "keep_until" {
  description = "Teardown date (YYYY-MM-DD), the cflt_keep_until tag. About 30 days out at most."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", var.keep_until))
    error_message = "keep_until must be YYYY-MM-DD."
  }
}

variable "owner_email" {
  description = "owner_email tag. Supplied from .env, never committed."
  type        = string

  validation {
    condition     = length(var.owner_email) > 0
    error_message = "owner_email must be set (OWNER_EMAIL in .env)."
  }
}

variable "owner_name" {
  description = "owner_name tag."
  type        = string

  validation {
    condition     = length(var.owner_name) > 0
    error_message = "owner_name must be set (OWNER_NAME in .env)."
  }
}

variable "managed_by" {
  description = "cflt_managed_by tag."
  type        = string

  validation {
    condition     = length(var.managed_by) > 0
    error_message = "managed_by must be set (TAG_MANAGED_BY or OWNER_NAME in .env)."
  }
}

variable "price_api_key" {
  description = "SerpAPI key. Stored only in the Lambda environment."
  type        = string
  sensitive   = true
}

variable "notify_email" {
  description = "SES sender and the only allowed recipient of deal emails (SES sandbox)."
  type        = string
  sensitive   = true
}

variable "llm_model" {
  description = "Confluent-hosted model used by the agent."
  type        = string
  default     = "anthropic.claude-sonnet-4-6"
}

variable "flink_max_cfu" {
  description = "Maximum CFUs for the Flink compute pool."
  type        = number
  default     = 5
}

locals {
  tags = {
    owner_email     = var.owner_email
    owner_name      = var.owner_name
    cflt_service    = "CSTA"
    cflt_managed_by = var.managed_by
    cflt_managed_id = var.project
    cflt_keep_until = var.keep_until
  }
}
