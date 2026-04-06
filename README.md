# Home server

Docker stack for a home server: media, download automation, MQTT broker, monitoring, TLS reverse proxy, and exposure via Cloudflare Tunnel.

The [`docker-compose.yml`](./docker-compose.yml) may use `include` to merge **another** Compose file on the same host (relative path). Services from that include use **their own `.env` files and variables** — check the YAML and the other repository’s documentation.

## Getting started

```bash
cd /path/to/homeserver   # your clone path on the host
cp .env.example .env
mkdir -p plex/config plex/media downloads radarr prowlarr qbittorrent emqx deye config/caddy/data config/caddy/config config/homepage
cp config/caddy/Caddyfile.example config/caddy/Caddyfile
# Edite config/caddy/Caddyfile: e-mail ACME, IPs de outros hosts, domínios reais
# deye: copia/cria deye/config.env a partir do que precisares para o inversor
```

Fill in **`.env`** here (Cloudflare Tunnel token, EMQX dashboard password, Plex claim). This compose file **`include`s** [`../jeronimofestas/docker-compose.yml`](./docker-compose.yml) — that app reads **`../jeronimofestas/.env`** (not this file). Configure that file separately; for production, set **`CORS_ORIGINS`** there (see Jerônimo Festas `.env.example`).

```bash
docker compose up -d
```

The Compose project name is `mnt` (`name: mnt` in the YAML) to keep networks and volumes stable.

### Estrutura de pastas

Os bind mounts apontam **diretamente** para pastas na raiz do repositório (sem `data/apps`, `iot` nem symlinks `media`).

| Caminho no compose | Uso |
|--------------------|-----|
| `plex/config`, `plex/media` | Config e biblioteca Plex (Radarr usa a mesma `plex/media`) |
| `radarr/`, `prowlarr/`, `qbittorrent/` | Configs *arr* / qBittorrent |
| `downloads/` | Torrents e importação |
| `emqx/`, `deye/` | Dados do broker MQTT e ficheiros do ponte Deye (`deye/config.env`) |
| `config/caddy/Caddyfile`, `config/caddy/data`, `config/caddy/config` | Config do proxy (ficheiro ativo em `config/caddy/` apenas; não há Caddyfile na raiz do repo) |
| `config/homepage/` | YAML do dashboard (versionáveis) |
| `infra/vault/config/` | `vault.hcl` (dados do Vault = volume Docker `vault_data`) |

O **`config/caddy/Caddyfile` ativo não é versionado** (e-mail ACME, IPs, domínios); o `docker-compose.yml` monta **só** esse caminho em `/etc/caddy/Caddyfile`. Use [`config/caddy/Caddyfile.example`](./config/caddy/Caddyfile.example) como modelo.

---

## Networking

- **`net_services`**: bridge `172.16.18.0/24`. Serviços em bridge recebem IP via DHCP interno do Docker (sem IP fixo no compose deste ficheiro), exceto os definidos no compose incluído **Jeronimo Festas** (`172.16.18.20`–`23`).
- **`network_mode: host`**: **Caddy**, **Cloudflare Tunnel**, **Plex**, and **Netdata** attach directly to the host network stack (DLNA/Plex discovery, proxy on all interfaces, and full host visibility for monitoring). O Caddy em **host** não resolve nomes DNS de contentores; no `Caddyfile`, o upstream típico neste host é o **IP LAN do servidor** (ex.: `192.169.0.231:porta`); `127.0.0.1:porta` também funciona na mesma máquina.

---

## Netdata

The stack runs **Netdata** in **host network mode** with the mounts recommended in the [official Docker guide](https://learn.netdata.cloud/docs/installing/docker): host `/proc`, `/sys`, read-only root (`/`), `docker.sock`, logs, and D-Bus where available. The UI listens on the host at **`http://<host>:19999`**. Configuration and cache use Docker **named volumes** (`netdataconfig`, `netdatalib`, `netdatacache`) — they are not bind-mounted under this repo.

For **HTTPS** on the LAN, configure **`netdata.lan`** in **`config/caddy/Caddyfile`** com **`reverse_proxy 127.0.0.1:19999`** (serviços neste host) ou o **IP LAN** se o Netdata estiver doutra máquina, e **`tls internal`** — trust Caddy’s local CA on your devices (or accept the browser warning). O exemplo em [`config/caddy/Caddyfile.example`](./config/caddy/Caddyfile.example) usa `127.0.0.1` para serviços locais. Plain HTTP stays at `http://<host>:19999` without the proxy.

---

## Services in this repository

| Service | Role | Ports / typical access |
|---------|------|-------------------------|
| **Homepage** | Dashboard (Docker socket + labels) | Corre como **root** no contentor para ler `docker.sock` e listar contentores (recomendação upstream). **HTTPS:** `https://homeserver.lan`. **HTTP directo:** `http://<IP_LAN>:3000` (não uses `https://…:3000`). |
| **Vault** | Secrets KV (modo ficheiro, um nó) | UI/API em `https://vault.lan`; host `127.0.0.1:8200` — inicializar e unseal após primeiro `up` |
| **Caddy** | HTTPS reverse proxy, automatic certificates, multiple `.lan` hosts and public domains | `config/caddy/Caddyfile` (copy from [`config/caddy/Caddyfile.example`](./config/caddy/Caddyfile.example)); host mode |
| **Cloudflare Tunnel** | Exposes services on the internet without opening ports on the router (token in `.env`) | Host mode |
| **Plex** | Media server | Host mode — UI usually at `http://<host>:32400` (LAN) |
| **Netdata** | Real-time monitoring: CPU, RAM, disk, network, **Docker containers** (read-only `docker.sock`), host logs | **Host network** — `http://<host>:19999` or **HTTPS** via Caddy (e.g. `https://netdata.lan`) |
| **Watchtower** | Periodic Docker image updates (1 h interval) | No UI |
| **EMQX** | **MQTT broker** on the LAN: ingests messages from sensors and publishers and delivers them to subscribers (e.g. Home Assistant). Central place for telemetry topics. | **1883** (MQTT), **8083/8084** (WebSocket), **18083** (web dashboard) on the host (prefer HTTPS via Caddy, e.g. `emqx.lan`) |
| **deye-mqtt** | **Bridge** between a **Deye solar inverter** (Modbus) and MQTT: reads production, battery, consumption, etc., and **publishes topics** to EMQX. Config em `deye/config.env`. | No published host port — only talks to the broker on the Docker network |
| **Radarr** | Movie library management | **7878** on the host (HTTPS via Caddy recommended) |
| **Prowlarr** | Indexer manager for the *arr* stack | **9696** on the host |
| **qBittorrent** | BitTorrent client | **9090** (WebUI), **6881** TCP/UDP (P2P) on the host |

Dados persistentes: vê a tabela **Estrutura de pastas** acima. Volume Docker: `vault_data`.

---

## What each piece is for

- **Netdata**: single dashboard for host health and **all** containers (CPU, memory, network, restarts); alerts and extra plugins in Netdata’s docs.
- **Plex**: library using `plex/media` (shared with Radarr to import movies after download).
- **Radarr + Prowlarr + qBittorrent**: typical flow — Prowlarr feeds indexers, Radarr manages movies and sends downloads to `downloads/`, then imports into `plex/media/` for Plex. **Isto não é “duplicação do compose”:** precisas das duas pastas — torrents em `downloads/`, biblioteca em `plex/media/`. Se **o mesmo filme ocupa o dobro do espaço** em disco, no Radarr vai a **Settings → Media Management** e usa **Hard Link** ou **Move** (não **Copy**) para importar; `downloads/` e `plex/media/` estão no mesmo host/repo, por isso *hard links* costumam funcionar. Opcional: em **Completed Download Handling**, remover da pasta de download após import. Ficheiros antigos em `downloads/` podes apagar manualmente depois de confirmares que a cópia em `plex/media/` está boa.
- **Solar (deye-mqtt + EMQX)**: **deye-mqtt** polls the **Deye inverter (solar / hybrid)** and sends data to **EMQX**. **Home Assistant** (or another MQTT client on your LAN) **subscribes to those topics** for charts, automations, and alerts on generation, consumption, and battery. EMQX is the message hub; deye-mqtt translates the inverter to MQTT.
- **Caddy**: one TLS entry point for internal services (e.g. `*.lan`) and, if configured, public sites behind Cloudflare Tunnel.
- **Watchtower**: keeps images up to date; check logs if a service should **pin** a specific image version.

---

## Security notes (Watchtower, Netdata, Docker socket)

- **Watchtower** mounts the **Docker socket** with full access. If its container or a malicious image were compromised, that can lead to **host takeover**. Mitigations: pin trusted image digests, restrict who can schedule stacks, or prefer **manual** image updates and disable Watchtower.
- **Netdata** runs with **high capabilities** and a **read-only `docker.sock`** mount for container visibility. Keep **`19999`** (and the proxied `netdata.lan` URL) on a **trusted LAN** only; do not expose monitoring UIs to the internet without authentication.
- **Service UIs** (Radarr, Prowlarr, qBittorrent Web, EMQX dashboard) are published on the **host**; use **HTTPS on `*.lan`** via Caddy as the main entry point. **Vault** escuta **127.0.0.1:8200** no host (só local ou via Caddy em `vault.lan`). **Homepage** publica **3000** em todas as interfaces; HTTPS recomendado via Caddy (`homeserver.lan`).
- **Vault**: guarde as chaves de unseal e o root token fora do servidor; após reinício do contentor, `vault operator unseal`. Para KV: ativar engine `kv-v2`, criar políticas e tokens com permissão mínima.

---

## External documentation

- [Netdata](https://www.netdata.cloud/) · [Netdata on Docker](https://learn.netdata.cloud/docs/installing/docker) · [Plex](https://support.plex.tv/) · [EMQX](https://www.emqx.io/docs) · [Home Assistant — MQTT](https://www.home-assistant.io/integrations/mqtt/)  
- [LinuxServer Radarr / Prowlarr / qBittorrent](https://docs.linuxserver.io/) · [Caddy](https://caddyserver.com/docs/) · [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)

---

## License

Personal / private configuration; Docker images follow their respective upstream licenses.
