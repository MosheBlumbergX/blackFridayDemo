# Flink SQL objects: MCP connection, model, tool, agent, source table and the
# continuous job that runs the agent on every wanted product.

locals {
  catalog  = confluent_environment.demo.display_name
  database = confluent_kafka_cluster.demo.display_name
  mcp_url  = "${trimsuffix(aws_lambda_function_url.mcp.function_url, "/")}/mcp"

  flink_props = {
    "sql.current-catalog"  = confluent_environment.demo.display_name
    "sql.current-database" = confluent_kafka_cluster.demo.display_name
  }

  agent_prompt = <<-EOT
    You are a Black Friday deal hunter for UK shoppers. For each request you do the following.

    1. Call the search_prices tool once with the PRODUCT QUERY from the request.
    2. If the tool returns found=false, the verdict is NO_DATA. Stop and do not send an email.
    3. Otherwise decide the verdict using ONLY the numbers the tool returned. Look at the cheapest listing:
       - FAKE_DISCOUNT: the cheapest listing has claimed_saving_pct of 20 or more, but cheapest_below_median_pct is below 5. The headline saving is not real, because the price is no lower than other shops.
       - BEST_DEAL: otherwise, if cheapest_below_median_pct is 10 or more and listing_count is at least 3.
       - OK_PRICE: in every other case.
    4. If the verdict is BEST_DEAL or FAKE_DISCOUNT, call the send_email tool once. The to parameter must be the single string given as EMAIL RECIPIENT. Use the subject and a short plain text body of two or three sentences: the product, the shop, the price, the median price, and why you reached the verdict.

    Reply in exactly this plain text format, with no markdown and no emoji:

    Verdict:
    [BEST_DEAL, FAKE_DISCOUNT, OK_PRICE or NO_DATA]

    Cheapest Shop:
    [shop name, or Not found]

    Cheapest Price:
    [price as XX.XX, or Not found]

    Median Price:
    [price as XX.XX, or Not found]

    Summary:
    [One sentence describing what you found and what you did]
  EOT
}

# ---------------------------------------------------------------- connection
resource "confluent_flink_statement" "mcp_connection" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.demo.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.demo.id
  }
  principal {
    id = confluent_service_account.app.id
  }
  rest_endpoint = data.confluent_flink_region.demo.rest_endpoint
  credentials {
    key    = confluent_api_key.flink.id
    secret = confluent_api_key.flink.secret
  }

  statement_name = "deal-mcp-connection"
  statement      = <<-EOT
    CREATE CONNECTION IF NOT EXISTS `deal-mcp-connection`
    WITH (
      'type' = 'MCP_SERVER',
      'endpoint' = '${local.mcp_url}',
      'token' = '${random_password.mcp_token.result}',
      'transport-type' = 'STREAMABLE_HTTP'
    );
  EOT
  properties     = local.flink_props

  # The API does not return the token, so the statement text always looks changed.
  # To rotate the token, taint this resource instead.
  lifecycle {
    ignore_changes = [statement]
  }

  depends_on = [confluent_role_binding.app_env_admin, aws_lambda_permission.url_invoke]
}

# --------------------------------------------------------------------- model
resource "confluent_flink_statement" "model" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.demo.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.demo.id
  }
  principal {
    id = confluent_service_account.app.id
  }
  rest_endpoint = data.confluent_flink_region.demo.rest_endpoint
  credentials {
    key    = confluent_api_key.flink.id
    secret = confluent_api_key.flink.secret
  }

  statement_name = "deal-model"
  statement      = <<-EOT
    CREATE MODEL IF NOT EXISTS deal_model
    INPUT (prompt STRING)
    OUTPUT (response STRING)
    WITH (
      'provider' = 'confluent',
      'task' = 'text_generation',
      'confluent.model' = '${var.llm_model}',
      'confluent.params.max_tokens' = '4000',
      'mcp.connection' = 'deal-mcp-connection'
    );
  EOT
  properties     = local.flink_props

  depends_on = [confluent_flink_statement.mcp_connection]
}

# ---------------------------------------------------------------------- tool
resource "confluent_flink_statement" "tool" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.demo.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.demo.id
  }
  principal {
    id = confluent_service_account.app.id
  }
  rest_endpoint = data.confluent_flink_region.demo.rest_endpoint
  credentials {
    key    = confluent_api_key.flink.id
    secret = confluent_api_key.flink.secret
  }

  statement_name = "deal-tool"
  statement      = <<-EOT
    CREATE TOOL deal_mcp_tool
    USING CONNECTION `deal-mcp-connection`
    WITH (
      'type' = 'mcp',
      'allowed_tools' = 'search_prices, send_email',
      'request_timeout' = '60'
    );
  EOT
  properties     = local.flink_props

  depends_on = [confluent_flink_statement.mcp_connection]
}

# --------------------------------------------------------------------- agent
resource "confluent_flink_statement" "agent" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.demo.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.demo.id
  }
  principal {
    id = confluent_service_account.app.id
  }
  rest_endpoint = data.confluent_flink_region.demo.rest_endpoint
  credentials {
    key    = confluent_api_key.flink.id
    secret = confluent_api_key.flink.secret
  }

  statement_name = "deal-agent"
  statement      = <<-EOT
    CREATE AGENT deal_hunter
    USING MODEL deal_model
    USING PROMPT '${local.agent_prompt}'
    USING TOOLS deal_mcp_tool
    COMMENT 'Finds the best Black Friday price and flags fake discounts'
    WITH (
      'max_consecutive_failures' = '2',
      'MAX_ITERATIONS' = '8'
    );
  EOT
  properties     = local.flink_props

  depends_on = [confluent_flink_statement.model, confluent_flink_statement.tool]
}

# -------------------------------------------------------------- source table
resource "confluent_flink_statement" "wanted_products" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.demo.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.demo.id
  }
  principal {
    id = confluent_service_account.app.id
  }
  rest_endpoint = data.confluent_flink_region.demo.rest_endpoint
  credentials {
    key    = confluent_api_key.flink.id
    secret = confluent_api_key.flink.secret
  }

  statement_name = "deal-wanted-products"
  statement      = <<-EOT
    CREATE TABLE IF NOT EXISTS wanted_products (
      run_id STRING,
      product_id STRING,
      product_query STRING
    ) WITH (
      'changelog.mode' = 'append',
      'value.format' = 'json-registry'
    );
  EOT
  properties     = local.flink_props

  depends_on = [confluent_role_binding.app_env_admin]
}

# ------------------------------------------------------------ the agent job
resource "confluent_flink_statement" "deal_job" {
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.demo.id
  }
  compute_pool {
    id = confluent_flink_compute_pool.demo.id
  }
  principal {
    id = confluent_service_account.app.id
  }
  rest_endpoint = data.confluent_flink_region.demo.rest_endpoint
  credentials {
    key    = confluent_api_key.flink.id
    secret = confluent_api_key.flink.secret
  }

  statement_name = "deal-verdicts-job"
  statement      = <<-EOT
    CREATE TABLE deal_verdicts
    WITH ('value.format' = 'json-registry', 'changelog.mode' = 'append')
    AS
    SELECT
      w.run_id,
      w.product_id,
      w.product_query,
      r.status AS agent_status,
      TRIM(REGEXP_EXTRACT(CAST(r.response AS STRING), 'Verdict:\s*([A-Z_]+)', 1)) AS verdict,
      TRIM(REGEXP_EXTRACT(CAST(r.response AS STRING), 'Cheapest Shop:\s*\n?([^\n]+)', 1)) AS cheapest_shop,
      TRIM(REGEXP_EXTRACT(CAST(r.response AS STRING), 'Cheapest Price:\s*\n?([^\n]+)', 1)) AS cheapest_price,
      TRIM(REGEXP_EXTRACT(CAST(r.response AS STRING), 'Median Price:\s*\n?([^\n]+)', 1)) AS median_price,
      TRIM(REGEXP_EXTRACT(CAST(r.response AS STRING), 'Summary:\s*\n?([\s\S]+?)$', 1)) AS summary,
      CAST(r.response AS STRING) AS raw_response
    FROM wanted_products w,
    LATERAL TABLE(
      AI_RUN_AGENT(
        'deal_hunter',
        CONCAT(
          'PRODUCT QUERY: ', w.product_query, '
          EMAIL RECIPIENT: the configured recipient
          EMAIL SUBJECT PREFIX: Black Friday deal alert - '
        ),
        CONCAT(w.run_id, '-', w.product_id),
        MAP['debug', 'true']
      )
    ) AS r(status, response);
  EOT
  properties     = local.flink_props

  # A running CREATE TABLE ... AS job cannot be re-created (the table already exists),
  # so never replace it because its text changed. To change the job, drop it first.
  lifecycle {
    ignore_changes = [statement]
  }

  depends_on = [
    confluent_flink_statement.agent,
    confluent_flink_statement.wanted_products,
  ]
}
