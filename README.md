# REALITY self-hosted cover site

A small HTTPS cover site for an Xray/3x-ui REALITY inbound. Caddy obtains and renews a real certificate while listening on a loopback-only HTTPS port. Xray keeps the public TCP/443 port and uses the local Caddy listener as its REALITY target.

The container uses the official, version-pinned `caddy:2.11.4-alpine` image rather than a floating `latest` tag.
The included GitHub Actions workflow validates the shell scripts, Compose model and Caddy configuration on every push.

## Network layout

```text
Internet :443/TCP  -> Xray REALITY
Internet :80/TCP   -> Caddy (ACME HTTP-01 and HTTPS redirect)
127.0.0.1:9443     -> Caddy HTTPS cover site
REALITY target     -> 127.0.0.1:9443
REALITY serverName -> cover.example.com
```

The public DNS record for the chosen domain must point to the server. TCP ports 80 and 443 must be open. Nothing else should occupy host port 80. The Caddy HTTPS listener is deliberately bound to `127.0.0.1`, so it is not directly exposed on port 9443.

## Deploy

```bash
git clone YOUR_REPOSITORY_URL reality-cover
cd reality-cover
cp .env.example .env
nano .env
chmod +x deploy.sh check.sh
./deploy.sh
```

Example `.env`:

```dotenv
SITE_DOMAIN=cover.example.com
ACME_EMAIL=admin@example.com
SITE_VARIANT=aurora
LOCAL_HTTPS_PORT=9443
```

Available page variants are `aurora`, `fjord`, and `northline`. Choose a different domain and variant on each server. Do not commit `.env`; it is ignored by Git.

The deployment stops before changing anything if DNS is missing, the system clock is unsynchronized, port 80 is occupied, or the Compose configuration is invalid. For a stricter DNS check, set `SERVER_PUBLIC_IP` in `.env`.

Watch the first certificate issuance:

```bash
docker compose logs -f cover-site
```

Then verify both the public site and loopback target:

```bash
./check.sh
```

Do not configure REALITY until `check.sh` prints `All checks passed`. It verifies the public endpoint, the loopback endpoint with the correct SNI, certificate hostname/chain and HTTP/2 ALPN.

## 3x-ui REALITY settings

Create a new VLESS inbound rather than modifying the last working configuration.

### Transport / XHTTP

| Setting | Value |
| --- | --- |
| Host | empty |
| Path | a random path, e.g. `/fi-m7q4pk2d/` |
| Mode | `packet-up` |
| Max upload size | `1000000` |
| Max buffered uploads | `30` |
| Min upload interval | `30-50` |
| Server Max Header Bytes | `0` |
| Padding Bytes | `100-1000` |
| Uplink method | default (`POST`) |
| Session placement | default (`path`) |
| Sequence placement | default (`path`) |
| XMUX, Sockopt, masks, QUIC | off for the first test |

### Security / REALITY

| Setting | Value |
| --- | --- |
| Security | `REALITY` |
| Target / Dest | `127.0.0.1:9443` |
| Server Names | the exact `SITE_DOMAIN` value |
| Show | off |
| Xver | `0` |
| Short ID | newly generated, even-length hexadecimal |
| SpiderX | `/` |
| Fingerprint on client | `chrome` |
| Flow | empty |

Generate a new REALITY key pair and re-import the connection URL/QR into the client. The exported client must contain the same path, SNI, public key, short ID and `mode=packet-up`.

## If 3x-ui is also in Docker

`127.0.0.1` inside the 3x-ui container is the container itself, not the host. Either run 3x-ui with host networking, or make the host gateway reachable from that container and use:

```text
Target: host.docker.internal:9443
```

On Linux Compose, the 3x-ui service may need:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

Keep port 9443 firewalled from the public Internet.

## Operations

```bash
# Status
docker compose ps

# Logs
docker compose logs --tail=100 cover-site

# Pull the current Caddy image and restart
docker compose pull
docker compose up -d

# Stop without deleting certificates
docker compose down
```

Caddy certificates and account data live in named Docker volumes. Do not run `docker compose down -v` unless you intentionally want to erase them.

## Availability limitations

This setup prevents dependency on an unrelated third-party REALITY target, but it cannot make a blocked VPS address reachable. For continuity, use at least two servers in different providers/ASNs, a different domain and REALITY key pair on each server, and distribute both profiles to clients in advance. Keep one separate RAW + REALITY inbound as a diagnostic/fallback profile; if RAW works but XHTTP does not, the problem is the client or XHTTP layer rather than the certificate target.
