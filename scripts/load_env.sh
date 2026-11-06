#!/usr/bin/env bash
# Source gitignored .env into current shell. Never echo secret values.
ENV_FILE="${ENV_FILE:-/Users/darklord/dev/dotnetapm/.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  return 1 2>/dev/null || exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
: "${ELASTIC_APM_SERVER_URL:?}"
: "${ELASTIC_APM_API_KEY:?}"
: "${ES_URL:?}"
: "${ES_API_KEY:?}"
: "${KIBANA_URL:?}"
