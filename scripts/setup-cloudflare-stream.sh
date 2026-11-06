#!/usr/bin/env bash
#
# Wires Cloudflare Stream into the Firebase backend and deploys the two
# streaming functions.
#
# Unlike the AWS script this replaced, there is nothing to provision up front:
# `createStreamCredentials` creates a live input per creator on their first Go
# Live. This only stores the two values that function needs and deploys it.
#
# Run from the repo root:  ./scripts/setup-cloudflare-stream.sh
#
# You need two things from the Cloudflare dashboard first — see PREREQUISITES.
#
# COSTS: Cloudflare Stream bills per minute of video stored and per minute
# delivered. A live input nobody streams to costs nothing.

set -euo pipefail

cat <<'PREREQUISITES'
PREREQUISITES — collect these from https://dash.cloudflare.com first:

1. ACCOUNT ID
   Easiest: open Stream in the dashboard and read it out of the URL —
   https://dash.cloudflare.com/<THIS BIT>/stream
   32 hex characters. (The "zone Overview sidebar" route only works if you
   have a domain on Cloudflare, which you may not.)

2. STREAM API TOKEN
   My Profile > API Tokens > Create Token > Custom token.
   Permission:  Account | Stream | Edit
   Nothing else. This token can create live inputs, so scope it narrowly.

PREREQUISITES

read -r -p "Have both? [y/N] " ready
[[ "$ready" == "y" || "$ready" == "Y" ]] || { echo "Collect them first, then re-run."; exit 0; }

# -s so none of these land in the terminal scrollback or shell history.
read -r -p  "Cloudflare account ID : " CF_ACCOUNT
read -rs -p "Stream API token      : " CF_TOKEN; echo

[ -n "$CF_ACCOUNT" ] && [ -n "$CF_TOKEN" ] || {
  echo "ERROR: both values are required."; exit 1; }

# --------------------------------------------------------------- verify
# Check the token BEFORE storing it. A bad token stored as a secret surfaces
# later as a generic "could not provision a streaming channel" at Go Live,
# which points at the app rather than at the credential.
echo "==> Verifying token against the Stream API..."
HTTP=$(curl -s -o /tmp/cf-verify.json -w '%{http_code}' \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT}/stream/live_inputs?per_page=1")

if [ "$HTTP" != "200" ]; then
  echo "ERROR: Cloudflare returned HTTP ${HTTP}. Nothing was stored."
  echo

  # Cloudflare puts the *useful* diagnosis in `messages`, not `errors`. The
  # errors array says "Authorization Failure" for every 403 — including the
  # case where the credentials are perfectly valid and the product simply is
  # not subscribed. Reading only `errors` sends you to re-make a token that
  # was never the problem.
  DETAIL=$(grep -o '"message": *"[^"]*"' /tmp/cf-verify.json | sed 's/"message": *"//;s/"$//' | tail -1)

  case "$DETAIL" in
    *"not enabled"*|*"not subscribed"*)
      echo "DIAGNOSIS: your credentials are fine — Stream is not enabled on this account."
      echo "  Subscribe at: https://dash.cloudflare.com/${CF_ACCOUNT}/stream"
      echo "  If you already paid, you likely subscribed under a DIFFERENT account."
      echo "  Check the account switcher; the ID in the /stream URL must be ${CF_ACCOUNT}." ;;
    *)
      echo "Check the account ID, and that the token has Account > Stream > Edit." ;;
  esac

  echo
  echo "Full response:"
  sed -n '1,20p' /tmp/cf-verify.json
  rm -f /tmp/cf-verify.json
  exit 1
fi
rm -f /tmp/cf-verify.json
echo "    token OK"

# --------------------------------------------------------------- secrets
# Piped via stdin so the values never appear in `ps` output or shell history.
echo "==> Storing Firebase secrets..."
set_secret() {
  printf '%s' "$2" | firebase functions:secrets:set "$1" --data-file - --force >/dev/null
  echo "    set $1"
}
set_secret CLOUDFLARE_ACCOUNT_ID   "$CF_ACCOUNT"
set_secret CLOUDFLARE_STREAM_TOKEN "$CF_TOKEN"

# ---------------------------------------------------------------- deploy
# FUNCTIONS_DISCOVERY_TIMEOUT is mandatory on this machine: the default 10s
# analyzer timeout fails with "Cannot determine backend specification", which
# is a handshake timeout and not a problem with the code.
echo "==> Deploying streaming functions..."
FUNCTIONS_DISCOVERY_TIMEOUT=120 firebase deploy --force --only \
  functions:createStreamCredentials,functions:listLiveChannels

cat <<'DONE'

Done. Go Live should now work end to end.

The first Go Live for each creator provisions their own Cloudflare live input
and caches it in creatorChannels/{uid}; later sessions reuse it.

If Go Live fails, check in this order:
  1. firebase functions:log --only createStreamCredentials
  2. "Streaming is not configured on the server" => a secret is missing.
  3. "Streaming host is not in the approved allowlist" => Cloudflare returned an
     ingest host other than live.cloudflare.com. Add it to
     StreamingSecurityPolicy.allowedIngestHosts; that is deliberately a code
     change, not configuration.
DONE
