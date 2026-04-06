# Vault single-node (file storage). TLS terminado no Caddy na LAN.
# Primeira execução: `docker compose exec vault vault operator init` (guarde chaves e root token)
# Depois: `vault operator unseal` (3 vezes com as key shares) em cada restart do container.

ui = true
disable_mlock = true

storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
}
