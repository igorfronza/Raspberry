#!/usr/bin/env bash
set -euo pipefail

# Etapa 5: Home Assistant (container Docker)
# Uso:
#   sudo bash scripts/05-homeassistant.sh
#   sudo bash scripts/05-homeassistant.sh /caminho/para/.env

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "[ERRO] Rode como root: sudo bash $0"
  exit 1
fi

ENV_FILE="${1:-$(dirname "$0")/.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  echo "[INFO] Variáveis carregadas de: $ENV_FILE"
else
  echo "[INFO] Arquivo .env não encontrado (ok). Usando padrões."
fi

HA_BASE_DIR="${HA_BASE_DIR:-/opt/homeassistant}"
HA_TZ="${HA_TZ:-America/Sao_Paulo}"
HA_HTTP_PORT="${HA_HTTP_PORT:-8123}"
HA_IMAGE="${HA_IMAGE:-ghcr.io/home-assistant/home-assistant:stable}"

if [[ "$HA_HTTP_PORT" != "8123" ]]; then
  echo "[WARN] O Home Assistant está em network_mode=host; a porta HTTP permanece 8123."
  echo "[WARN] Ignorando HA_HTTP_PORT=$HA_HTTP_PORT e usando 8123."
  HA_HTTP_PORT="8123"
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose
fi

systemctl enable docker
systemctl restart docker

mkdir -p "$HA_BASE_DIR/config"

cat > "$HA_BASE_DIR/docker-compose.yml" <<YAML
services:
  homeassistant:
    image: ${HA_IMAGE}
    container_name: homeassistant
    restart: unless-stopped
    network_mode: host
    environment:
      - TZ=${HA_TZ}
    volumes:
      - ${HA_BASE_DIR}/config:/config
YAML

if docker compose version >/dev/null 2>&1; then
  docker compose -f "$HA_BASE_DIR/docker-compose.yml" up -d
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose -f "$HA_BASE_DIR/docker-compose.yml" up -d
else
  echo "[ERRO] Nem docker compose nem docker-compose estão disponíveis."
  exit 1
fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow "${HA_HTTP_PORT}/tcp" || true
fi

echo "[OK] Etapa 5 concluída."
echo "[INFO] Home Assistant: http://IP_DO_RASPBERRY:${HA_HTTP_PORT}"
