#!/usr/bin/env bash
set -euo pipefail

# Etapa 3: Pi-hole em container Docker
# Uso:
#   sudo bash scripts/03-pihole.sh
#   sudo bash scripts/03-pihole.sh /caminho/para/.env

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

PIHOLE_BASE_DIR="${PIHOLE_BASE_DIR:-/opt/pihole}"
PIHOLE_WEBPASSWORD="${PIHOLE_WEBPASSWORD:-}"
PIHOLE_TZ="${PIHOLE_TZ:-America/Sao_Paulo}"
PIHOLE_DNS1="${PIHOLE_DNS1:-1.1.1.1}"
PIHOLE_DNS2="${PIHOLE_DNS2:-8.8.8.8}"
PIHOLE_HOST_IP="${PIHOLE_HOST_IP:-}"
PIHOLE_HTTP_PORT="${PIHOLE_HTTP_PORT:-8080}"
PIHOLE_IMAGE="${PIHOLE_IMAGE:-pihole/pihole:latest}"

if [[ -z "$PIHOLE_WEBPASSWORD" ]]; then
  echo "[ERRO] Defina PIHOLE_WEBPASSWORD no scripts/.env"
  exit 1
fi

if [[ -z "$PIHOLE_HOST_IP" ]]; then
  PIHOLE_HOST_IP="$(hostname -I | awk '{print $1}')"
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io

# Em algumas versões do Raspberry Pi OS, docker-compose-plugin não existe no apt.
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose
fi

systemctl enable docker
systemctl restart docker

mkdir -p "$PIHOLE_BASE_DIR/etc-pihole" "$PIHOLE_BASE_DIR/etc-dnsmasq.d"

cat > "$PIHOLE_BASE_DIR/docker-compose.yml" <<YAML
services:
  pihole:
    image: ${PIHOLE_IMAGE}
    container_name: pihole
    hostname: pihole
    restart: unless-stopped
    environment:
      TZ: "${PIHOLE_TZ}"
      WEBPASSWORD: "${PIHOLE_WEBPASSWORD}"
      PIHOLE_DNS_: "${PIHOLE_DNS1};${PIHOLE_DNS2}"
      FTLCONF_LOCAL_IPV4: "${PIHOLE_HOST_IP}"
    volumes:
      - "${PIHOLE_BASE_DIR}/etc-pihole:/etc/pihole"
      - "${PIHOLE_BASE_DIR}/etc-dnsmasq.d:/etc/dnsmasq.d"
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "${PIHOLE_HTTP_PORT}:80/tcp"
    cap_add:
      - NET_ADMIN
YAML

if docker compose version >/dev/null 2>&1; then
  docker compose -f "$PIHOLE_BASE_DIR/docker-compose.yml" up -d
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose -f "$PIHOLE_BASE_DIR/docker-compose.yml" up -d
else
  echo "[ERRO] Nem docker compose nem docker-compose estão disponíveis."
  exit 1
fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow 53/tcp || true
  ufw allow 53/udp || true
  ufw allow "${PIHOLE_HTTP_PORT}/tcp" || true
fi

echo "[OK] Etapa 3 concluída."
echo "[INFO] Painel Pi-hole: http://${PIHOLE_HOST_IP}:${PIHOLE_HTTP_PORT}/admin"
echo "[INFO] DNS da rede deve apontar para: ${PIHOLE_HOST_IP}"
