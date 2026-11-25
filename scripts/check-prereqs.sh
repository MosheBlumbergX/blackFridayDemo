#!/usr/bin/env bash
# Checks tools and .env variable names. Prints names only, never values.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

section "Tools"
for t in terraform python3 aws jq zip; do
  command -v "$t" >/dev/null && ok "found $t" || die "missing tool: $t"
done

section ".env"
load_env
require_vars CONFLUENT_CLOUD_API_KEY CONFLUENT_CLOUD_API_SECRET PRICE_API_KEY \
  NOTIFY_EMAIL OWNER_EMAIL OWNER_NAME KEEP_UNTIL
ok "all required variables are set"

section "Tag check"
[[ "${KEEP_UNTIL}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "KEEP_UNTIL must be YYYY-MM-DD"
ok "keep-until ${KEEP_UNTIL}"

section "AWS identity"
aws sts get-caller-identity --query Arn --output text >/dev/null && ok "AWS credentials work" \
  || die "AWS credentials not working (check AWS_PROFILE)"
