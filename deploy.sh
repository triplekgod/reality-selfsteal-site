#!/usr/bin/env sh
set -eu

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env. Set SITE_DOMAIN and ACME_EMAIL, then run this script again." >&2
  exit 1
fi

./preflight.sh

set -a
# shellcheck disable=SC1091
. ./.env
set +a

docker compose config --quiet
docker compose pull
docker compose run --rm --no-deps cover-site \
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker compose up -d
docker compose ps

printf '\nPublic site:   https://%s\n' "$SITE_DOMAIN"
printf 'REALITY target: 127.0.0.1:%s\n' "${LOCAL_HTTPS_PORT:-9443}"
printf 'REALITY SNI:    %s\n' "$SITE_DOMAIN"

