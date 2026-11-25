#!/usr/bin/env bash
# Print the latest verdicts already on the topic.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
[[ -f "${GENERATED}/client.env" ]] || die "Run 'make up' first."
cd "${REPO_ROOT}/clients/python"
exec .venv/bin/python show_verdicts.py --expect "${1:-5}" --timeout 30
