#!/usr/bin/env bash
# Runs terraform with .env loaded: scripts/tf.sh plan | apply | destroy | ...
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
load_env
require_vars CONFLUENT_CLOUD_API_KEY CONFLUENT_CLOUD_API_SECRET PRICE_API_KEY \
  NOTIFY_EMAIL OWNER_EMAIL OWNER_NAME KEEP_UNTIL
cd "${REPO_ROOT}/terraform"
exec terraform "$@"
