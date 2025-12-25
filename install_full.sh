#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo "=========================================="
echo "BELABOX SRTLA MONOLITH INSTALLER (2025)"
echo "=========================================="

# ──────────────────────────────────────────────
# ✅ Определяем реального пользователя
TARGET_USER="${SUDO_USER:-$(whoami)}"
TARGET_HOME="$(eval echo ~${TARGET_USER})"

echo "Установка для пользователя: $TARGET_USER"
echo "Домашняя директория пользователя: $TARGET_HOME"

# ──────────────────────────────────────────────
# 1️⃣ Обновляем пакеты и ставим зависимости
sudo apt update
sudo apt install -y build-essential cmake git libssl-dev pkg-config tcl libva-dev ufw fail2ban wget unzip

# ──────────────────────────────────────────────
# 2️⃣ Создаём рабочую директорию
BELABOX_DIR="/opt/belabox"
sudo mkdir -p "$BELABOX_DIR"
sudo chown "$TARGET_USER":"$TARGET_USER" "$BELABOX_DIR"

cd "$BELABOX_DIR"

# ──────────────────────────────────────────────
# 3️⃣ Скачиваем и собираем patched SRT
if [ -d "patched_srt" ]; then
    cd patched_srt
    git fetch --all --prune
    git reset --hard origin/master
else
    git clone https://github.com/BELABOX/srt.git patched_srt
    cd patched_srt
fi

./configure --cmake-install-prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig

cd "$BELABOX_DIR"

# ──────────────────────────────────────────────
# 4️⃣ Скачиваем и собираем SRTLA
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

make clean || true
make -j"$(nproc)"

# ──────────────────────────────────────────────
# 5️⃣ Настройка безопасности (UFW + Fail2Ban)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 5002/udp
sudo ufw allow 6000/udp
sudo ufw --force enable

sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo sed -i 's/^enabled *=.*/enabled = true/' /etc/fail2ban/jail.local
sudo sed -i 's/^port *=.*/port = ssh/' /etc/fail2ban/jail.local
sudo sed -i 's/^maxretry *=.*/maxretry = 5/' /etc/fail2ban/jail.local
sudo sed -i 's/^bantime *=.*/bantime = 3600/' /etc/fail2ban/jail.local
sudo sed -i 's/^findtime *=.*/findtime = 600/' /etc/fail2ban/jail.local

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

# ──────────────────────────────────────────────
# 6️⃣ Создаём systemd сервис srtla_rec
cat >/tmp/srtla_rec.service <<EOF
[Unit]
Description=Belabox SRTLA Receiver
After=network.target
Wants=srt_receiver.service

[Service]
Type=simple
User=$TARGET_USER
WorkingDirectory=$BELABOX_DIR/srtla
ExecStart=$BELABOX_DIR/srtla/srtla_rec 5002 127.0.0.1 5000
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/srtla_rec.service /etc/systemd/system/srtla_rec.service

# ──────────────────────────────────────────────
# 7️⃣ Создаём systemd сервис для SRT ретранслятора
cat >/tmp/srt_receiver.service <<EOF
[Unit]
Description=SRT Receiver (port 5000) → SRT Relay (port 6000)
After=network.target
Before=srtla_rec.service

[Service]
Type=simple
User=$TARGET_USER
WorkingDirectory=$BELABOX_DIR

# Основной запуск: SRT → SRT
ExecStart=/usr/local/bin/srt-live-transmit "srt://0.0.0.0:5000?mode=listener" "srt://0.0.0.0:6000?mode=listener"

Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/srt_receiver.service /etc/systemd/system/srt_receiver.service

# ──────────────────────────────────────────────
# 8️⃣ Включаем и запускаем сервисы
sudo systemctl daemon-reload
sudo systemctl enable srt_receiver srtla_rec
sudo systemctl start srt_receiver

sleep 2

sudo systemctl start srtla_rec

# ──────────────────────────────────────────────
# 9️⃣ Проверяем статус
echo ""
echo "=========================================="
echo "Проверка запущенных сервисов:"
echo "=========================================="
sudo systemctl status srt_receiver --no-pager
echo ""
sudo systemctl status srtla_rec --no-pager
echo ""

echo "=========================================="
echo "Проверяем открытые порты:"
echo "=========================================="
sudo ss -tulpn | grep -E ':(5000|5002|6000)' || true
echo ""

echo "=========================================="
echo "✅ Установка завершена! SRTLA запущен и настроен."
echo ""

# ──────────────────────────────────────────────
# 🔁 Получаем внешний IP автоматически
EXT_IP=$(curl -s ifconfig.me || echo "ВАШ_IP_НЕ_ОПРЕДЕЛЕН")

echo "Ваш внешний IP: $EXT_IP"
echo ""

# ──────────────────────────────────────────────
# 📌 Информация для клиента и OBS
echo "Настройки для Belabox (SRTLA):"
echo "  srtla://$EXT_IP:5002"
echo ""
echo "Настройки для приёма потока (OBS):"
echo "  srt://$EXT_IP:6000/?streamid=play/stream/<your_stream_id>"
echo ""
echo "Открытые порты:"
echo "  22/tcp  - SSH"
echo "  5002/udp - входящий SRTLA (от Belabox)"
echo "  6000/udp - исходящий SRT (для клиентов)"
echo ""
echo "=========================================="
