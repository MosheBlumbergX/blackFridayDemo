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

- Lab 1 compares one competitor. The deal hunter compares several shops and also checks a price history to catch fake "was" prices.
- Shops are mock sites that we host ourselves, so nothing scrapes a real retailer (terms of service, and a public repo).
- Prompts and the final verdict are kept structured so the result can be parsed and counted.

## Open questions (to confirm during the build)

- Is the Flink agent feature available in AWS `eu-west-2`? If not, fall back to `eu-west-1`.
- Which model access path: Confluent-hosted inference or own Bedrock keys.
- Which MCP backend for `http_get` and `send_email`: Confluent-hosted (needs a token) or Zapier.

## Sources

- https://docs.confluent.io/cloud/current/ai/streaming-agents/overview.html
- https://docs.confluent.io/cloud/current/ai/streaming-agents/create-and-run-streaming-agents.html
- https://docs.confluent.io/cloud/current/flink/reference/statements/create-agent.html
- https://docs.confluent.io/cloud/current/ai/builtin-functions/invoke-tool-ai-workflow.html
