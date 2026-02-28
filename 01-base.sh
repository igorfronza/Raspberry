#!/usr/bin/env bash
set -euo pipefail

# Etapa 1: preparação base do sistema (idempotente)
# Uso:
#   sudo bash scripts/01-base.sh
#   sudo DRY_RUN=1 bash scripts/01-base.sh
#   sudo bash scripts/01-base.sh /caminho/para/.env

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

DRY_RUN="${DRY_RUN:-0}"
TZ_VALUE="${TZ_VALUE:-America/Sao_Paulo}"
LOCALE_VALUE="${LOCALE_VALUE:-pt_BR.UTF-8}"
PI_HOSTNAME="${PI_HOSTNAME:-raspberrypi}"
ENABLE_UFW="${ENABLE_UFW:-1}"
ENABLE_FAIL2BAN="${ENABLE_FAIL2BAN:-1}"
SSH_DISABLE_PASSWORD="${SSH_DISABLE_PASSWORD:-0}"
HAS_SYSTEMD=0
[[ -d /run/systemd/system ]] && HAS_SYSTEMD=1

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY_RUN] $*"
  else
    eval "$@"
  fi
}

apt_install_if_missing() {
  local pkg
  for pkg in "$@"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      echo "[OK] Pacote já instalado: $pkg"
    else
      run_cmd "apt-get install -y $pkg"
    fi
  done
}

echo "[INFO] Iniciando etapa 1 (base do sistema)..."

run_cmd "apt-get update"
run_cmd "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"

apt_install_if_missing \
  curl wget ca-certificates gnupg lsb-release jq unzip \
  git vim htop net-tools \
  openssh-server ufw fail2ban unattended-upgrades

if [[ "$HAS_SYSTEMD" == "1" ]]; then
  CURRENT_TZ="$(timedatectl show --property=Timezone --value 2>/dev/null || true)"
  if [[ "$CURRENT_TZ" != "$TZ_VALUE" ]]; then
    run_cmd "timedatectl set-timezone '$TZ_VALUE'"
  else
    echo "[OK] Timezone já configurado: $TZ_VALUE"
  fi
else
  echo "[WARN] Sem systemd neste ambiente: pulando ajuste de timezone via timedatectl."
fi

if ! locale -a 2>/dev/null | grep -qi "^${LOCALE_VALUE//./\.}$"; then
  run_cmd "sed -i 's/^# *${LOCALE_VALUE} UTF-8/${LOCALE_VALUE} UTF-8/' /etc/locale.gen || true"
  run_cmd "locale-gen ${LOCALE_VALUE}"
fi
run_cmd "update-locale LANG=${LOCALE_VALUE}"

CURRENT_HOSTNAME="$(hostname 2>/dev/null || true)"
if [[ -n "$PI_HOSTNAME" && "$CURRENT_HOSTNAME" != "$PI_HOSTNAME" ]]; then
  if [[ "$HAS_SYSTEMD" == "1" ]]; then
    run_cmd "hostnamectl set-hostname '$PI_HOSTNAME'"
  else
    run_cmd "hostname '$PI_HOSTNAME'"
    if [[ "$DRY_RUN" != "1" ]]; then
      echo "$PI_HOSTNAME" > /etc/hostname
    else
      echo "[DRY_RUN] escrever $PI_HOSTNAME em /etc/hostname"
    fi
  fi

  if [[ "$DRY_RUN" != "1" ]]; then
    if grep -q "127.0.1.1" /etc/hosts; then
      sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$PI_HOSTNAME/" /etc/hosts
    else
      echo -e "127.0.1.1\t$PI_HOSTNAME" >> /etc/hosts
    fi
  else
    echo "[DRY_RUN] ajustar /etc/hosts para $PI_HOSTNAME"
  fi
else
  echo "[OK] Hostname já configurado: $CURRENT_HOSTNAME"
fi

if [[ "$ENABLE_UFW" == "1" ]]; then
  run_cmd "ufw allow OpenSSH"
  run_cmd "ufw --force enable"
fi

if [[ "$ENABLE_FAIL2BAN" == "1" ]]; then
  if [[ "$HAS_SYSTEMD" == "1" ]]; then
    run_cmd "systemctl enable fail2ban"
    run_cmd "systemctl restart fail2ban"
  else
    echo "[WARN] Sem systemd: fail2ban não foi habilitado automaticamente."
  fi
fi

if [[ "$HAS_SYSTEMD" == "1" ]]; then
  run_cmd "systemctl enable unattended-upgrades"
  run_cmd "systemctl restart unattended-upgrades"
else
  echo "[WARN] Sem systemd: unattended-upgrades não foi habilitado automaticamente."
fi

if [[ "$SSH_DISABLE_PASSWORD" == "1" ]]; then
  if [[ "$DRY_RUN" != "1" ]]; then
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
  else
    echo "[DRY_RUN] desabilitar PasswordAuthentication e root login no sshd_config"
  fi

  if [[ "$HAS_SYSTEMD" == "1" ]]; then
    run_cmd "systemctl restart ssh"
  else
    echo "[WARN] Sem systemd: reinício do SSH não executado automaticamente."
  fi
fi

echo "[OK] Etapa 1 concluída."
echo "[INFO] Próximo passo: rodar scripts/02-storage.sh (quando você quiser)."
