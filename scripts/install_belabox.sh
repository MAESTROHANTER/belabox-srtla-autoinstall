#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

echo "=== УСТАНОВКА BELABOX patched SRT + SRTLA (новый формат 2025) ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$SCRIPT_DIR"

echo "Установка зависимостей..."
sudo apt update
sudo apt install -y build-essential cmake git libssl-dev pkg-config tcl libva-dev

# ========== PATCHED SRT ==========
echo ""
echo "Клонируем / обновляем patched SRT..."
if [ -d "patched_srt" ]; then
    cd patched_srt
    git fetch --all --prune
    git reset --hard origin/master
else
    git clone https://github.com/BELABOX/srt.git patched_srt
    cd patched_srt
fi

echo "Собираем patched SRT..."
./configure --cmake-install-prefix=/usr/local
make -j$(nproc)
sudo make install
sudo ldconfig
cd "$SCRIPT_DIR"

# ========== SRTLA ==========
echo ""
echo "Клонируем/обновляем SRTLA..."
if [ -d "srtla" ]; then
    cd srtla
    git fetch --all --prune
    MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    git checkout "$MAIN_BRANCH"
    git reset --hard "origin/$MAIN_BRANCH"
else
    git clone https://github.com/BELABOX/srtla.git srtla
    cd srtla
fi

echo "Собираем SRTLA..."
make clean || true
make -j$(nproc)

echo ""
echo "SRTLA УСПЕШНО УСТАНОВЛЕН!"
echo "Файлы:"
echo " → $SCRIPT_DIR/srtla/srtla_rec"
echo " → $SCRIPT_DIR/srtla/srtla_send"
