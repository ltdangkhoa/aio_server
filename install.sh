#!/bin/bash

set -e

echo "===== Enable root SSH key login ====="

mkdir -p /root/.ssh
cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

systemctl restart ssh

echo "===== Update system ====="

apt update
apt upgrade -y

echo "===== Install base tools ====="

apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  ncdu \
  htop \
  btop

echo "===== Install Docker ====="

mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
| gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" \
> /etc/apt/sources.list.d/docker.list

apt update

apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "===== Create Caddy network ====="

docker network create caddy || true

echo "===== Setup Caddy ====="

mkdir -p /root/caddy/data
mkdir -p /root/caddy/config

cat <<'EOT' > /root/caddy/docker-compose.yml
services:
  caddy:
    image: lucaslorentz/caddy-docker-proxy:ci-alpine
    ports:
      - 80:80
      - 443:443/tcp
      - 443:443/udp
    environment:
      - CADDY_INGRESS_NETWORKS=caddy
    networks:
      - caddy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/data
      - ./config:/config
    restart: unless-stopped

networks:
  caddy:
    external: true
EOT

cd /root/caddy
docker compose up -d

echo "===== DONE ====="
echo "Installed: docker, ncdu, htop, btop"
echo "SSH root login enabled."
