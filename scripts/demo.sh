#!/usr/bin/env bash
# The scripted run, with section headers so it can be screen-recorded.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

PY="${REPO_ROOT}/clients/python"
[[ -f "${GENERATED}/client.env" ]] || die "Run 'make up' first."

section "1. Python environment"
[[ -d "${PY}/.venv" ]] || python3 -m venv "${PY}/.venv"
"${PY}/.venv/bin/pip" install -q -r "${PY}/requirements.txt"
ok "ready"

section "2. Publish the Christmas shopping list"
note "Five gift ideas go onto the wanted_products topic."
(cd "${PY}" && .venv/bin/python produce_wants.py --runs 1)

section "3. The Flink agent searches real UK shop prices"
note "Per product: search_prices (MCP) -> verdict -> send_email if it is a BEST_DEAL or FAKE_DISCOUNT."
(cd "${PY}" && .venv/bin/python show_verdicts.py --expect 5 --timeout 420)

section "4. Done"
note "Check your inbox for the deal alerts."
