#!/usr/bin/env sh
set -eu

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

note() {
  echo "OK: $*"
}

command -v docker >/dev/null 2>&1 || \
  fail "Docker is required: https://docs.docker.com/engine/install/"
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is required."
[ -f .env ] || fail "Missing .env (copy .env.example first)."

set -a
# shellcheck disable=SC1091
. ./.env
set +a

[ -n "${SITE_DOMAIN:-}" ] || fail "SITE_DOMAIN is empty."
[ "$SITE_DOMAIN" != "cover.example.com" ] || fail "Replace the example SITE_DOMAIN."
[ -n "${ACME_EMAIL:-}" ] || fail "ACME_EMAIL is empty."
[ "$ACME_EMAIL" != "admin@example.com" ] || fail "Replace the example ACME_EMAIL."

case "$SITE_DOMAIN" in
  *[!A-Za-z0-9.-]*|.*|*.) fail "SITE_DOMAIN is not a plain DNS name." ;;
esac

case "${SITE_VARIANT:-aurora}" in
  aurora|fjord|northline) note "page variant is ${SITE_VARIANT:-aurora}" ;;
  *) fail "SITE_VARIANT must be aurora, fjord, or northline." ;;
esac

case "${LOCAL_HTTPS_PORT:-9443}" in
  ''|*[!0-9]*) fail "LOCAL_HTTPS_PORT must be numeric." ;;
esac

resolved=""
if command -v getent >/dev/null 2>&1; then
  resolved=$(getent ahostsv4 "$SITE_DOMAIN" | awk 'NR == 1 { print $1 }')
elif command -v dig >/dev/null 2>&1; then
  resolved=$(dig +short A "$SITE_DOMAIN" | awk 'NR == 1 { print $1 }')
else
  fail "Install getent or dig so DNS can be checked."
fi

[ -n "$resolved" ] || fail "$SITE_DOMAIN does not have a resolvable IPv4 A record."
note "$SITE_DOMAIN resolves to $resolved"

if [ -n "${SERVER_PUBLIC_IP:-}" ] && [ "$resolved" != "$SERVER_PUBLIC_IP" ]; then
  fail "$SITE_DOMAIN resolves to $resolved, expected SERVER_PUBLIC_IP=$SERVER_PUBLIC_IP"
fi

if command -v timedatectl >/dev/null 2>&1; then
  ntp_state=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)
  [ "$ntp_state" != "no" ] || fail "system clock is not NTP-synchronized."
fi

docker compose config --quiet || fail "compose.yaml or .env is invalid."
note "Docker Compose configuration is valid"

if command -v ss >/dev/null 2>&1; then
  if [ -z "$(docker compose ps --quiet cover-site 2>/dev/null)" ] && \
     ss -ltnH '( sport = :80 )' 2>/dev/null | grep -q .; then
    fail "TCP port 80 is already occupied; Caddy needs it for ACME HTTP-01."
  fi
fi

note "preflight checks passed"
