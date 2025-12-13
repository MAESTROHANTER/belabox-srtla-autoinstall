#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

echo "=========================================="
echo "BELABOX SRTLA MONOLITH INSTALLER (2025)"
echo "=========================================="

# 1️⃣ Обновляем пакеты и ставим зависимости
apt update
apt install -y build-essential cmake git libssl-dev pkg-config tcl libva-dev ufw fail2ban wget unzip &>/dev/null || true

# 2️⃣ Создаём рабочую директорию
BELABOX_DIR=/opt/belabox
SRTLA_DIR=$BELABOX_DIR/srtla
mkdir -p "$BELABOX_DIR"
cd "$BELABOX_DIR"

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
make -j$(nproc)
make install
ldconfig
cd "$BELABOX_DIR"

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
make -j$(nproc)

# 5️⃣ Настройка безопасности (UFW + Fail2Ban)
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 5002/udp
ufw allow 6000/udp
ufw --force enable

cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i 's/^enabled *=.*/enabled = true/' /etc/fail2ban/jail.local
sed -i 's/^port *=.*/port = ssh/' /etc/fail2ban/jail.local
sed -i 's/^maxretry *=.*/maxretry = 5/' /etc/fail2ban/jail.local
sed -i 's/^bantime *=.*/bantime = 3600/' /etc/fail2ban/jail.local
sed -i 's/^findtime *=.*/findtime = 600/' /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl restart fail2ban

# 6️⃣ Создаём systemd сервис srtla_rec
cat >/etc/systemd/system/srtla_rec.service <<'EOF'
[Unit]
Description=Belabox SRTLA Receiver
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/belabox/srtla
ExecStart=/opt/belabox/srtla/srtla_rec 5002 0.0.0.0 5000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable srtla_rec
systemctl start srtla_rec

echo ""
echo "=========================================="
echo "✅ Install complete! SRTLA patched + autostartup"
echo "Open ports: 22/SSH, 5002/SRT in, 6000/SRT out"
echo "=========================================="
