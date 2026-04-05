# Home server

Stack Docker para um servidor em casa: multimídia, automação de downloads, broker MQTT, monitoramento, reverse proxy com TLS e exposição via Cloudflare Tunnel.

O [`docker-compose.yml`](./docker-compose.yml) pode usar `include` para mesclar **outro** arquivo Compose no mesmo host (caminho relativo). Serviços vindos desse include usam **variáveis e arquivos `.env` próprios daquele projeto** — consulte o YAML e a documentação do outro repositório.

## Como subir

```bash
cd /mnt/homeserver   # ajuste para o caminho no seu host
cp .env.example .env
cp Caddyfile.example Caddyfile
# Edite Caddyfile: email Let's Encrypt, IPs do host e domínios reais
```

Preencha o **`.env`** deste diretório (Cloudflare Tunnel, EMQX, Plex claim, etc.). Se o `include` apontar para outro compose, crie/ajuste também o `.env` exigido por esse arquivo (ver `env_file` e variáveis no próprio YAML).

```bash
docker compose up -d
```

O nome do projeto Compose é `mnt` (`name: mnt` no YAML), para manter redes e volumes estáveis. Os dados persistentes ficam em subpastas deste diretório (`plex/`, `emqx/`, …); elas estão no `.gitignore` e não vão para o Git.

O **`Caddyfile` real também não é versionado** (evita expor no Git seu email ACME, IPs da LAN, domínios públicos e mapa dos serviços). No repositório existe só [`Caddyfile.example`](./Caddyfile.example) como modelo.

---

## Rede

- **`net_services`**: bridge `172.16.18.0/24`. A maioria dos **containers** tem IP fixo na faixa `172.16.18.x`.
- **`network_mode: host`**: **Caddy**, **Cloudflare Tunnel** e **Plex** — conectam direto à pilha de rede do host (útil para descoberta DLNA/Plex e para o proxy escutar em todas as interfaces).

---

## Serviços descritos neste repositório

| Serviço | Função | Portas / acesso típico |
|---------|--------|-------------------------|
| **Caddy** | Reverse proxy HTTPS, certificados automáticos, vários hosts `.lan` e domínios públicos | Arquivo `Caddyfile` (local; copie de [`Caddyfile.example`](./Caddyfile.example)); modo host |
| **Cloudflare Tunnel** | Expõe serviços na internet sem abrir porta no roteador (token no `.env`) | Modo host |
| **Plex** | Servidor de mídia | Modo host — interface em geral `http://<host>:32400` (rede local) |
| **Netdata** | Monitoramento em tempo real: CPU, RAM, disco, rede, **containers Docker** (via `docker.sock` só leitura), logs do host | **`19999`** (ex.: `http://<host>:19999`) |
| **Watchtower** | Atualização periódica de imagens Docker (intervalo 1 h) | Sem UI |
| **EMQX** | **Broker MQTT** na rede local: recebe mensagens de sensores e publicadores, e entrega para assinantes (ex.: Home Assistant). Centraliza tópicos de telemetria. | **1883** (MQTT), **8083/8084** (WebSocket), **18083** (dashboard web) |
| **deye-mqtt** | **Ponte** entre o **inversor solar Deye** (protocolo Modbus) e o MQTT: lê produção, bateria, consumo etc. no inversor e **publica tópicos** no EMQX. Configuração em `deye/config.env`. | Sem porta publicada — só fala com o broker na rede Docker |
| **Radarr** | Gerenciamento de filmes para a biblioteca | **7878** |
| **Prowlarr** | Indexadores para o ecossistema *arr* | **9696** |
| **qBittorrent** | Cliente BitTorrent | **9090** (WebUI), **6881** TCP/UDP |

Pastas de dados: `plex/` (config + media), `emqx/`, `deye/`, `radarr/`, `prowlarr/`, `qbittorrent/`, `downloads/` (compartilhada entre Radarr/qBittorrent), `caddy/data` e `caddy/config` (certificados e estado).

---

## O que dá para fazer com cada parte

- **Netdata**: painel único para a saúde do host e lista de **todos** os containers (CPU, memória, rede, restarts); alertas e plugins extras na documentação oficial do Netdata.
- **Plex**: biblioteca com a pasta `plex/media` (compartilhada com o Radarr para importar filmes depois do download).
- **Radarr + Prowlarr + qBittorrent**: fluxo típico — o Prowlarr alimenta indexadores, o Radarr gerencia filmes e envia downloads para `downloads/`, depois importa na biblioteca do Plex.
- **Energia solar (deye-mqtt + EMQX)**: o **deye-mqtt** consulta o **inversor (placa solar / híbrido Deye)** e envia os dados para o **EMQX**. O **Home Assistant** (ou outro cliente MQTT na sua rede) **assina esses tópicos** e monta gráficos, automações e alertas de geração, consumo e bateria. O EMQX é o “hub” de mensagens; o deye-mqtt é só quem traduz o inversor para MQTT.
- **Caddy**: um único ponto de entrada com TLS para serviços internos (ex. `*.lan`) e, se configurado, sites públicos atrás do Cloudflare Tunnel.
- **Watchtower**: mantém imagens atualizadas; vale revisar os logs se algum serviço precisar de **versão fixa** da imagem.

---

## Documentação externa

- [Netdata](https://www.netdata.cloud/) · [Plex](https://support.plex.tv/) · [EMQX](https://www.emqx.io/docs) · [Home Assistant — MQTT](https://www.home-assistant.io/integrations/mqtt/)  
- [LinuxServer Radarr / Prowlarr / qBittorrent](https://docs.linuxserver.io/) · [Caddy](https://caddyserver.com/docs/) · [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)

---

## Licença

Configuração pessoal / privada; as imagens Docker seguem as licenças dos respectivos projetos.
