#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive

echo "===== Configure needrestart (auto) ====="

mkdir -p /etc/needrestart/conf.d
echo '$nrconf{restart} = "a";' > /etc/needrestart/conf.d/auto-restart.conf

echo "===== Enable root SSH key login ====="

mkdir -p /root/.ssh

if [ -f /home/ubuntu/.ssh/authorized_keys ]; then
  cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/
fi

chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys || true
chown -R root:root /root/.ssh

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

systemctl restart ssh || systemctl restart sshd

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
  btop \
  git \
  ufw

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

systemctl enable docker
systemctl start docker

echo "===== Configure Firewall ====="

ufw allow 22
ufw allow 80
ufw allow 443
ufw --force enable

echo "===== Create Caddy network ====="

docker network create caddy || true

echo "===== Setup Caddy ====="

mkdir -p /root/caddy/data
mkdir -p /root/caddy/config

cat <<'EOT' > /root/caddy/docker-compose.yml
services:
  caddy:
    image: lucaslorentz/caddy-docker-proxy:ci-alpine
    container_name: caddy
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

echo "===== Cleanup ====="

apt autoremove -y

echo "===== DONE ====="
echo "Docker + Caddy installed"
echo "Monitoring tools: ncdu / htop / btop"
echo "Firewall enabled"
echo "Root SSH key login enabled"
