#!/bin/bash
set -e

echo "=== Настройка безопасности ==="

apt install -y ufw fail2ban

# ========== UFW ==========
ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp
ufw allow 5002/udp
ufw allow 6000/udp
ufw --force enable

# ========== Fail2Ban ==========
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

sed -i 's/^enabled *=.*/enabled = true/' /etc/fail2ban/jail.local
sed -i 's/^port *=.*/port = ssh/' /etc/fail2ban/jail.local
sed -i 's/^maxretry *=.*/maxretry = 5/' /etc/fail2ban/jail.local
sed -i 's/^bantime *=.*/bantime = 3600/' /etc/fail2ban/jail.local
sed -i 's/^findtime *=.*/findtime = 600/' /etc/fail2ban/jail.local

systemctl enable fail2ban
systemctl restart fail2ban

echo "=== Безопасность настроена ==="
