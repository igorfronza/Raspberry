#!/usr/bin/env bash
set -euo pipefail

# Etapa 4: WireGuard VPN (wg-easy em Docker)
# Uso:
#   sudo bash scripts/04-wireguard.sh
#   sudo bash scripts/04-wireguard.sh /caminho/para/.env

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

WG_BASE_DIR="${WG_BASE_DIR:-/opt/wireguard}"
WG_HOST="${WG_HOST:-}"
WG_PORT="${WG_PORT:-51820}"
WG_WEB_PORT="${WG_WEB_PORT:-51821}"
WG_ADMIN_PASSWORD="${WG_ADMIN_PASSWORD:-}"
WG_ADMIN_PASSWORD_HASH="${WG_ADMIN_PASSWORD_HASH:-}"
WG_DEFAULT_DNS="${WG_DEFAULT_DNS:-1.1.1.1,8.8.8.8}"
WG_DEVICE="${WG_DEVICE:-eth0}"
WG_IMAGE="${WG_IMAGE:-ghcr.io/wg-easy/wg-easy:14}"

if [[ -z "$WG_HOST" ]]; then
  echo "[ERRO] Defina WG_HOST no scripts/.env (IP público ou DDNS)."
  exit 1
fi

if [[ -z "$WG_ADMIN_PASSWORD_HASH" && -z "$WG_ADMIN_PASSWORD" ]]; then
  echo "[ERRO] Defina WG_ADMIN_PASSWORD_HASH (recomendado) ou WG_ADMIN_PASSWORD no scripts/.env"
  exit 1
fi

if [[ -z "$WG_ADMIN_PASSWORD_HASH" && ( "$WG_IMAGE" == *":14"* || "$WG_IMAGE" == *":latest"* ) ]]; then
  echo "[ERRO] Para WG_IMAGE ${WG_IMAGE}, use WG_ADMIN_PASSWORD_HASH (bcrypt)."
  echo "       Gere assim: sudo docker run --rm ghcr.io/wg-easy/wg-easy:14 wgpw 'SUA_SENHA'"
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose
fi

systemctl enable docker
systemctl restart docker

mkdir -p "$WG_BASE_DIR"

cat > "$WG_BASE_DIR/docker-compose.yml" <<YAML
services:
  wg-easy:
    image: ${WG_IMAGE}
    container_name: wg-easy
    restart: unless-stopped
    environment:
      - WG_HOST=${WG_HOST}
      - WG_PORT=${WG_PORT}
      - WG_DEFAULT_DNS=${WG_DEFAULT_DNS}
      - WG_DEVICE=${WG_DEVICE}
      - WG_PERSISTENT_KEEPALIVE=25
      - UI_TRAFFIC_STATS=true
      - PASSWORD_HASH=${WG_ADMIN_PASSWORD_HASH}
    volumes:
      - ${WG_BASE_DIR}/data:/etc/wireguard
    ports:
      - "${WG_PORT}:${WG_PORT}/udp"
      - "${WG_WEB_PORT}:51821/tcp"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
YAML

# Compatibilidade para imagens legadas (< v14)
if [[ -z "$WG_ADMIN_PASSWORD_HASH" && -n "$WG_ADMIN_PASSWORD" ]]; then
  sed -i "/WG_HOST=.*/a \      - PASSWORD=${WG_ADMIN_PASSWORD}" "$WG_BASE_DIR/docker-compose.yml"
  sed -i "/PASSWORD_HASH=/d" "$WG_BASE_DIR/docker-compose.yml"
fi

if docker compose version >/dev/null 2>&1; then
  docker compose -f "$WG_BASE_DIR/docker-compose.yml" up -d
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose -f "$WG_BASE_DIR/docker-compose.yml" up -d
else
  echo "[ERRO] Nem docker compose nem docker-compose estão disponíveis."
  exit 1
fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow "${WG_PORT}/udp" || true
  ufw allow "${WG_WEB_PORT}/tcp" || true
fi

echo "[OK] Etapa 4 concluída."
echo "[INFO] Painel WireGuard: http://IP_DO_RASPBERRY:${WG_WEB_PORT}"
echo "[INFO] Endpoint VPN (cliente): ${WG_HOST}:${WG_PORT}"
