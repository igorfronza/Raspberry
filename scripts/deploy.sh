#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/homelab-setup"
mkdir -p "$LOG_DIR"

run_step() {
  local script="$1"
  local name
  name="$(basename "$script" .sh)"

  if [[ ! -f "$script" ]]; then
    echo "[ERRO] Script não encontrado: $script"
    exit 1
  fi

  echo "[INFO] Executando: $name"
  bash "$script" "$BASE_DIR/.env" 2>&1 | tee "$LOG_DIR/${name}.log"
}

run_step "$BASE_DIR/01-base.sh"
run_step "$BASE_DIR/02-storage.sh"
run_step "$BASE_DIR/03-pihole.sh"
run_step "$BASE_DIR/04-wireguard.sh"
run_step "$BASE_DIR/05-homeassistant.sh"

cat <<'MSG'
[OK] Etapas 1, 2, 3, 4 e 5 executadas.
Próximo passo: validações finais e backup da configuração.
MSG
