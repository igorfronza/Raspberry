#!/usr/bin/env bash
set -euo pipefail

# Copia pasta scripts/ para a partição root do microSD já montado.
# Uso:
#   bash scripts/copy-to-sd.sh /media/$USER/rootfs

if [[ $# -ne 1 ]]; then
  echo "Uso: $0 <caminho-montado-da-particao-root-do-sd>"
  exit 1
fi

TARGET_ROOT="$1"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$TARGET_ROOT/opt/homelab-setup"

if [[ ! -d "$TARGET_ROOT" ]]; then
  echo "[ERRO] Caminho não existe: $TARGET_ROOT"
  exit 1
fi

mkdir -p "$TARGET_DIR"
install -m 755 "$SOURCE_DIR/deploy.sh" "$TARGET_DIR/deploy.sh"
install -m 755 "$SOURCE_DIR/01-base.sh" "$TARGET_DIR/01-base.sh"
install -m 644 "$SOURCE_DIR/.env.example" "$TARGET_DIR/.env.example"

echo "[OK] Arquivos copiados para: $TARGET_DIR"
echo "[INFO] No Raspberry:"
echo "  sudo cp /opt/homelab-setup/.env.example /opt/homelab-setup/.env"
echo "  sudo bash /opt/homelab-setup/deploy.sh"
