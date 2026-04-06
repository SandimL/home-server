# Home server

Docker stack for a home server: media, download automation, MQTT broker, monitoring, TLS reverse proxy, and exposure via Cloudflare Tunnel.

The [`docker-compose.yml`](./docker-compose.yml) may use `include` to merge **another** Compose file on the same host (relative path). Services from that include use **their own `.env` files and variables** — check the YAML and the other repository’s documentation.

## Getting started

```bash
cd /mnt/homeserver   # adjust to the path on your host
cp .env.example .env
cp Caddyfile.example Caddyfile
# Edit Caddyfile: Let's Encrypt email, host IPs, and real domains
```

Fill in **`.env`** in this directory (Cloudflare Tunnel, EMQX, Plex claim, etc.). If `include` points at another compose file, create or adjust the `.env` required by that file as well (see `env_file` and variables in that YAML). For **Jerónimo Festas**, production requires **`CORS_ORIGINS`** (see that project’s `.env.example`).

```bash
docker compose up -d
```

The Compose project name is `mnt` (`name: mnt` in the YAML) to keep networks and volumes stable. Persistent data lives in subfolders here (`plex/`, `emqx/`, …); they are listed in `.gitignore` and are not committed to Git.

The **real `Caddyfile` is not versioned** either (avoids publishing your ACME email, LAN IPs, public domains, and service map on Git). This repo only ships [`Caddyfile.example`](./Caddyfile.example) as a template.

---

## Networking

- **`net_services`**: bridge `172.16.18.0/24`. Most **containers** use a static IP in `172.16.18.x`.
- **`network_mode: host`**: **Caddy**, **Cloudflare Tunnel**, **Plex**, and **Netdata** attach directly to the host network stack (DLNA/Plex discovery, proxy on all interfaces, and full host visibility for monitoring).

---

## Netdata

The stack runs **Netdata** in **host network mode** with the mounts recommended in the [official Docker guide](https://learn.netdata.cloud/docs/installing/docker): host `/proc`, `/sys`, read-only root (`/`), `docker.sock`, logs, and D-Bus where available. The UI listens on the host at **`http://<host>:19999`**. Configuration and cache use Docker **named volumes** (`netdataconfig`, `netdatalib`, `netdatacache`) — they are not bind-mounted under this repo.

For **HTTPS** on the LAN, configure **`netdata.lan`** in your local **`Caddyfile`** with the same upstream IP as your other services (e.g. `http://<host>:19999`) plus **`tls internal`** — trust Caddy’s local CA on your devices (or accept the browser warning). On the same Docker host you can use **`127.0.0.1:19999`** instead of the LAN IP if you prefer loopback. [`Caddyfile.example`](./Caddyfile.example) uses a placeholder. Plain HTTP stays at `http://<host>:19999` without the proxy.

---

## Services in this repository

| Service | Role | Ports / typical access |
|---------|------|-------------------------|
| **Caddy** | HTTPS reverse proxy, automatic certificates, multiple `.lan` hosts and public domains | Local `Caddyfile` (copy from [`Caddyfile.example`](./Caddyfile.example)); host mode |
| **Cloudflare Tunnel** | Exposes services on the internet without opening ports on the router (token in `.env`) | Host mode |
| **Plex** | Media server | Host mode — UI usually at `http://<host>:32400` (LAN) |
| **Netdata** | Real-time monitoring: CPU, RAM, disk, network, **Docker containers** (read-only `docker.sock`), host logs | **Host network** — `http://<host>:19999` or **HTTPS** via Caddy (e.g. `https://netdata.lan`) |
| **Watchtower** | Periodic Docker image updates (1 h interval) | No UI |
| **EMQX** | **MQTT broker** on the LAN: ingests messages from sensors and publishers and delivers them to subscribers (e.g. Home Assistant). Central place for telemetry topics. | **1883** (MQTT), **8083/8084** (WebSocket), **18083** (web dashboard) on the host (prefer HTTPS via Caddy, e.g. `emqx.lan`) |
| **deye-mqtt** | **Bridge** between a **Deye solar inverter** (Modbus) and MQTT: reads production, battery, consumption, etc., and **publishes topics** to EMQX. Config in `deye/config.env`. | No published host port — only talks to the broker on the Docker network |
| **Radarr** | Movie library management | **7878** on the host (HTTPS via Caddy recommended) |
| **Prowlarr** | Indexer manager for the *arr* stack | **9696** on the host |
| **qBittorrent** | BitTorrent client | **9090** (WebUI), **6881** TCP/UDP (P2P) on the host |

Data directories: `plex/` (config + media), `emqx/`, `deye/`, `radarr/`, `prowlarr/`, `qbittorrent/`, `downloads/` (shared by Radarr/qBittorrent), `caddy/data` and `caddy/config` (certificates and state).

---

## What each piece is for

- **Netdata**: single dashboard for host health and **all** containers (CPU, memory, network, restarts); alerts and extra plugins in Netdata’s docs.
- **Plex**: library using `plex/media` (shared with Radarr to import movies after download).
- **Radarr + Prowlarr + qBittorrent**: typical flow — Prowlarr feeds indexers, Radarr manages movies and sends downloads to `downloads/`, then imports into the Plex library.
- **Solar (deye-mqtt + EMQX)**: **deye-mqtt** polls the **Deye inverter (solar / hybrid)** and sends data to **EMQX**. **Home Assistant** (or another MQTT client on your LAN) **subscribes to those topics** for charts, automations, and alerts on generation, consumption, and battery. EMQX is the message hub; deye-mqtt translates the inverter to MQTT.
- **Caddy**: one TLS entry point for internal services (e.g. `*.lan`) and, if configured, public sites behind Cloudflare Tunnel.
- **Watchtower**: keeps images up to date; check logs if a service should **pin** a specific image version.

---

## Security notes (Watchtower, Netdata, Docker socket)

- **Watchtower** mounts the **Docker socket** with full access. If its container or a malicious image were compromised, that can lead to **host takeover**. Mitigations: pin trusted image digests, restrict who can schedule stacks, or prefer **manual** image updates and disable Watchtower.
- **Netdata** runs with **high capabilities** and a **read-only `docker.sock`** mount for container visibility. Keep **`19999`** (and the proxied `netdata.lan` URL) on a **trusted LAN** only; do not expose monitoring UIs to the internet without authentication.
- **Service UIs** (Radarr, Prowlarr, qBittorrent Web, EMQX dashboard) are published on the **host**; use **HTTPS on `*.lan`** via Caddy as the main entry point. If you ever bind those ports to **127.0.0.1** only in Compose, set Caddy’s `reverse_proxy` upstream to **127.0.0.1**, not the LAN IP.

---

## External documentation

- [Netdata](https://www.netdata.cloud/) · [Netdata on Docker](https://learn.netdata.cloud/docs/installing/docker) · [Plex](https://support.plex.tv/) · [EMQX](https://www.emqx.io/docs) · [Home Assistant — MQTT](https://www.home-assistant.io/integrations/mqtt/)  
- [LinuxServer Radarr / Prowlarr / qBittorrent](https://docs.linuxserver.io/) · [Caddy](https://caddyserver.com/docs/) · [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)

---

## License

Personal / private configuration; Docker images follow their respective upstream licenses.
