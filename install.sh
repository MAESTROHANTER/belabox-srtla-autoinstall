#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "  BELABOX SRTLA AUTO-INSTALLER (2025)"
echo "============================================"

# Загружаем конфиг
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
fi

# 1️⃣ Установка Belabox SRT/SRTLA
bash "$SCRIPT_DIR/scripts/install_belabox.sh"

# 2️⃣ Настройка безопасности
bash "$SCRIPT_DIR/scripts/harden_server.sh"

# 3️⃣ Настройка systemd автозапуска
echo "Настройка systemd сервисов..."
sudo cp "$SCRIPT_DIR/systemd/srtla_rec.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable srtla_rec
sudo systemctl start srtla_rec

echo ""
echo "============================================"
echo "  Установка завершена! SRTLA готов к работе."
echo "============================================"
