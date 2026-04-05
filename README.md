# Home server

Stack Docker do servidor: reverse proxy (Caddy), media, *arr*, MQTT, Netdata, túnel Cloudflare, etc. No host, o compose inclui o stack **Jeronimo Festas** (repositório [jeronimofestas](https://github.com/SandimL/jeronimofestas)) via `include`, com caminho relativo `../jeronimofestas/docker-compose.yml`.

## Uso

```bash
cd /mnt/homeserver   # ou o caminho desta pasta no teu host
cp .env.example .env
# Preencher .env; na mesma máquina, credenciais da app em <clone>/jeronimofestas/.env
docker compose up -d
```

Pastas ao lado deste repositório (`plex/`, `emqx/`, …) são criadas pelo Docker com dados em tempo de execução e estão listadas no `.gitignore`.
