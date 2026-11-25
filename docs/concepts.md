# Concepts

How the Black Friday deal hunter works, and the Confluent Cloud features it relies on.

## Streaming Agents in Confluent Cloud for Apache Flink

- A **tool** is a Flink resource created with `CREATE TOOL`. An MCP tool points at an MCP server through a `CREATE CONNECTION`.
- An **agent** is created with `CREATE AGENT`. It binds a model, a system prompt and a set of tools, and takes `max_iterations` and `max_consecutive_failures` settings.
- `AI_RUN_AGENT(agent, prompt, key, options)` runs the agent once per row, inside a continuous Flink job. It automates repeated `AI_TOOL_INVOKE` calls.
- `AI_TOOL_INVOKE` is the lower-level function: one model call that may call MCP tools or UDFs.
- Streaming Agents were introduced as a preview. Check current status and regional availability before every build.

## Reference pattern: Confluent Lab 1 (price matching)

Source: https://github.com/confluentinc/quickstart-streaming-agents/blob/master/LAB1-Walkthrough.md

1. Generate `customers`, `products` and `orders` streams.
2. Join them into `enriched_orders` (regular joins with a state TTL).
3. `CREATE TOOL` over a remote MCP connection exposing `http_get` and `send_email`.
4. `CREATE AGENT` with a prompt: scrape a competitor, extract the price, compare, email on a match.
5. `CREATE TABLE ... AS SELECT ... AI_RUN_AGENT(...)` runs the agent continuously and parses the structured reply with `REGEXP_EXTRACT`.

## Design differences for this demo

- Lab 1 compares one competitor. The deal hunter compares many UK shops for each product and checks any "old price" a shop claims against what the other shops charge, to catch fake discounts.
- Prices are real. They come from SerpAPI's Google Shopping search, not from scraping shop pages, so no retailer's terms of service are involved.
- Our own MCP server does the price maths (median, gap to the median, claimed saving) and filters out resale listings, so the model only judges numbers it is given.
- Prompts and the final verdict are kept structured so the result can be parsed and counted.

## Decisions made during the build

- **Region:** Flink is available in AWS `eu-west-2`, so everything runs in London.
- **Model:** Confluent-hosted inference (`'provider' = 'confluent'`, model `anthropic.claude-sonnet-4-6`), so no Bedrock keys are needed.
- **MCP server:** our own, on AWS Lambda behind a Function URL, built with Terraform. Confluent's hosted workshop server needs a token from a private list, so a public demo could not rely on it. It also keeps the SerpAPI key out of the agent prompt.
- **Email:** Amazon SES. In the sandbox, sender and recipient must both be verified, and mail from an address with no DKIM can land in Spam.

## Sources

- https://docs.confluent.io/cloud/current/ai/streaming-agents/overview.html
- https://docs.confluent.io/cloud/current/ai/streaming-agents/create-and-run-streaming-agents.html
- https://docs.confluent.io/cloud/current/flink/reference/statements/create-agent.html
- https://docs.confluent.io/cloud/current/ai/builtin-functions/invoke-tool-ai-workflow.html
