#!/usr/bin/env bash
# Shared helpers. Sourced by the other scripts, never executed directly.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED="${REPO_ROOT}/.generated"
mkdir -p "${GENERATED}"

BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'; RED=$'\033[31m'; RESET=$'\033[0m'
die()     { printf '%sERROR:%s %s\n' "${RED}" "${RESET}" "$*" >&2; exit 1; }
note()    { printf '%s%s%s\n' "${DIM}" "$*" "${RESET}"; }
section() { printf '\n%s== %s ==%s\n' "${BOLD}" "$*" "${RESET}"; }
ok()      { printf '%s%s%s\n' "${GREEN}" "$*" "${RESET}"; }

# Load .env and map it to the TF_VAR_* names Terraform expects.
# Values are never printed.
load_env() {
  [[ -f "${REPO_ROOT}/.env" ]] || die ".env not found. Copy .env.example to .env and fill it in."
  # A profile already set in your shell wins over an empty AWS_PROFILE= in .env.
  local shell_profile="${AWS_PROFILE:-}"
  set -a
  # shellcheck disable=SC1091
  . "${REPO_ROOT}/.env"
  set +a
  [[ -z "${shell_profile}" ]] || export AWS_PROFILE="${shell_profile}"
  [[ -n "${AWS_PROFILE:-}" ]] || unset AWS_PROFILE
  export AWS_REGION="${AWS_REGION:-eu-west-2}"
  export AWS_DEFAULT_REGION="${AWS_REGION}"
  export TF_VAR_price_api_key="${PRICE_API_KEY:-}"
  export TF_VAR_notify_email="${NOTIFY_EMAIL:-}"
  export TF_VAR_owner_email="${OWNER_EMAIL:-}"
  export TF_VAR_owner_name="${OWNER_NAME:-}"
  export TF_VAR_managed_by="${TAG_MANAGED_BY:-${OWNER_NAME:-}}"
  export TF_VAR_project="${PROJECT:-blackfridaydemo}"
  export TF_VAR_keep_until="${KEEP_UNTIL:-}"
  export TF_VAR_aws_region="${AWS_REGION}"
}

require_vars() {
  local missing=() v
  for v in "$@"; do [[ -n "${!v:-}" ]] || missing+=("$v"); done
  ((${#missing[@]} == 0)) || die "Missing in .env: ${missing[*]}"
}
