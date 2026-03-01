#!/usr/bin/env bash
set -euo pipefail

# Etapa 2: servidor de arquivos (Samba + SFTP via OpenSSH)
# Uso:
#   sudo bash scripts/02-storage.sh
#   sudo bash scripts/02-storage.sh /caminho/para/.env

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

STORAGE_BASE_DIR="${STORAGE_BASE_DIR:-/srv/homelab-storage}"
STORAGE_OWNER_USER="${STORAGE_OWNER_USER:-${SUDO_USER:-pi}}"
STORAGE_OWNER_GROUP="${STORAGE_OWNER_GROUP:-${STORAGE_OWNER_USER}}"
SMB_SHARE_NAME="${SMB_SHARE_NAME:-Storage}"
SMB_ENABLE="${SMB_ENABLE:-1}"
SMB_PASSWORD="${SMB_PASSWORD:-}"

PUBLIC_DIR="$STORAGE_BASE_DIR/public"
PRIVATE_DIR="$STORAGE_BASE_DIR/private"
SMB_CONF_FILE="/etc/samba/smb.conf"
MARK_BEGIN="# >>> homelab-storage begin >>>"
MARK_END="# <<< homelab-storage end <<<"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y samba

id "$STORAGE_OWNER_USER" >/dev/null 2>&1 || {
  echo "[ERRO] Usuário não encontrado: $STORAGE_OWNER_USER"
  exit 1
}

mkdir -p "$PUBLIC_DIR" "$PRIVATE_DIR"
chown -R "$STORAGE_OWNER_USER":"$STORAGE_OWNER_GROUP" "$STORAGE_BASE_DIR"
chmod 2775 "$STORAGE_BASE_DIR"
chmod 2775 "$PUBLIC_DIR"
chmod 2770 "$PRIVATE_DIR"

if [[ "$SMB_ENABLE" == "1" ]]; then
  if ! grep -q "^${MARK_BEGIN}$" "$SMB_CONF_FILE"; then
    cat >> "$SMB_CONF_FILE" <<CFG

${MARK_BEGIN}
[${SMB_SHARE_NAME}-Publico]
   path = ${PUBLIC_DIR}
   browseable = yes
   read only = no
   guest ok = no
   create mask = 0664
   directory mask = 0775

[${SMB_SHARE_NAME}-Privado]
   path = ${PRIVATE_DIR}
   browseable = yes
   read only = no
   guest ok = no
   valid users = ${STORAGE_OWNER_USER}
   force user = ${STORAGE_OWNER_USER}
   create mask = 0660
   directory mask = 0770
${MARK_END}
CFG
    echo "[OK] Bloco Samba adicionado em $SMB_CONF_FILE"
  else
    echo "[OK] Bloco Samba já existe em $SMB_CONF_FILE"
  fi

  if [[ -n "$SMB_PASSWORD" ]]; then
    (echo "$SMB_PASSWORD"; echo "$SMB_PASSWORD") | smbpasswd -s -a "$STORAGE_OWNER_USER" || true
    smbpasswd -e "$STORAGE_OWNER_USER" || true
    echo "[OK] Senha Samba aplicada para usuário: $STORAGE_OWNER_USER"
  else
    echo "[WARN] SMB_PASSWORD não definido. Defina no scripts/.env e rode:"
    echo "       sudo smbpasswd -a $STORAGE_OWNER_USER"
  fi

  systemctl enable smbd
  systemctl restart smbd
  systemctl enable nmbd || true
  systemctl restart nmbd || true

  if command -v ufw >/dev/null 2>&1; then
    ufw allow samba || true
  fi
fi

echo "[OK] Etapa 2 concluída."
echo "[INFO] Caminho local: $STORAGE_BASE_DIR"
echo "[INFO] SMB: \\IP_DO_RASPBERRY\\${SMB_SHARE_NAME}-Publico e \\IP_DO_RASPBERRY\\${SMB_SHARE_NAME}-Privado"
echo "[INFO] SFTP: use usuário Linux '$STORAGE_OWNER_USER' e pasta $STORAGE_BASE_DIR"
