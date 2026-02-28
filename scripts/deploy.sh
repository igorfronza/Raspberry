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

# Etapa 1 habilitada
run_step "$BASE_DIR/01-base.sh"

cat <<'MSG'
[OK] Etapa 1 executada.
Próximo passo: criar/rodar 02-storage.sh.
MSG
