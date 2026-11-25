# Troubleshooting

Real errors hit while building this demo, with the fix.

## `NoCredentials` from `make check`, although `AWS_PROFILE` is set in your shell

**Cause:** `.env.example` has an empty `AWS_PROFILE=`. Sourcing `.env` overwrote the profile from the shell, and `scripts/common.sh` then unset it.

**Fix:** `load_env` now keeps a profile that was already set in the shell. Or set `AWS_PROFILE` in `.env`.

## `aws sso login` says `Missing ... sso_start_url, sso_region`

**Cause:** the profile is managed by Granted (`credential_process = granted credential-process ...`), not by the AWS CLI's own SSO settings.

**Fix:** log in with Granted: `granted sso login --sso-start-url <your start url> --sso-region <region>`, then check with `aws sts get-caller-identity --profile <profile>`.

## `ResourceConflictException: The function could not be updated due to a concurrent update operation`

**Cause:** the AWS provider adds `lambda:InvokeFunctionUrl` itself when it creates a public Function URL. My own permission resources ran at the same time and collided with it.

**Fix:** removed the duplicate `InvokeFunctionUrl` permission and made the `InvokeFunction` permission depend on the URL. Re-run `make up`; the half-created URL is replaced.

## `Failed to write plan file ... no such file or directory`

**Cause:** `scripts/tf.sh` changes into `terraform/` before running Terraform, so a relative `-out=` path is wrong.

**Fix:** pass an absolute path to `-out`.

## `BASH_SOURCE[0]: parameter not set` when sourcing `scripts/common.sh`

**Cause:** the helper scripts are bash, and the command was run under zsh.

**Fix:** run them with `bash script.sh`, or through `make`.

## SerpAPI returns `401 Unauthorized` (also on `https://serpapi.com/account`)

**Cause:** the key in `.env` is not a valid SerpAPI key (it was 32 characters; check it on https://serpapi.com/manage-api-key).

**Fix:** copy the full key into `PRICE_API_KEY`, then run `make up`. Terraform updates the Lambda environment in place.

## Agent says "email sent" but nothing arrives

**Cause:** the MCP tool returned success, so the agent reports it as sent. Delivery is a separate question. Mail sent through SES from a plain address identity has no DKIM or SPF alignment, so it can go to Spam (here) or be dropped (a corporate address sending to itself delivered nothing visible at all).

**Fix:** search all mail including Spam for the subject. To check what really left AWS, read the Lambda log (`tool_call` and `email_sent` lines) and the SES send statistics (bounces and rejects). For a permanent fix, verify a domain in SES with DKIM.

## `make demo` shows verdicts from an earlier run

**Cause:** the viewer read `deal_verdicts` from the beginning, so a second run printed run 1's rows.

**Fix:** `produce_wants.py` records the run id in `.generated/last_run_id` and `show_verdicts.py` filters on it.

## `terraform plan` wants to replace the running Flink job (or the MCP connection)

**Cause:** changing text inside a `confluent_flink_statement` forces replacement, and the API never returns the connection token, so that statement always looks changed. A replaced `CREATE TABLE ... AS` job would fail because the table already exists.

**Fix:** `lifecycle { ignore_changes = [statement] }` on the connection and the job. Keep rule changes in the Lambda, not in the statement text.
