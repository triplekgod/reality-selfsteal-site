#!/usr/bin/env sh
set -eu

if [ ! -f .env ]; then
  echo "Missing .env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

port="${LOCAL_HTTPS_PORT:-9443}"

echo "Checking public HTTPS..."
curl --fail --silent --show-error --connect-timeout 10 --max-time 20 \
  "https://${SITE_DOMAIN}/healthz"
echo

echo "Checking local REALITY target with SNI..."
curl --fail --silent --show-error --connect-timeout 10 --max-time 20 \
  --resolve "${SITE_DOMAIN}:${port}:127.0.0.1" \
  "https://${SITE_DOMAIN}:${port}/healthz"
echo

echo "Checking certificate name and validity..."
if command -v openssl >/dev/null 2>&1; then
  cert_result=$(printf '' | openssl s_client \
    -connect "127.0.0.1:${port}" \
    -servername "$SITE_DOMAIN" \
    -verify_hostname "$SITE_DOMAIN" \
    -alpn h2 2>&1)
  echo "$cert_result" | grep -q "Verify return code: 0 (ok)" || {
    echo "$cert_result" >&2
    echo "Certificate verification failed." >&2
    exit 1
  }
  negotiated=$(echo "$cert_result" | sed -n 's/^ALPN protocol: //p' | head -n 1)
  [ "$negotiated" = "h2" ] || {
    echo "Expected HTTP/2 ALPN, got: ${negotiated:-none}" >&2
    exit 1
  }
  echo "Certificate is valid and HTTP/2 was negotiated."
else
  echo "openssl is not installed; curl certificate verification passed, ALPN check skipped."
fi

echo "All checks passed. The local endpoint is suitable as a REALITY target."
