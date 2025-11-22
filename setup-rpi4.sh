#!/bin/bash
set -e

echo "========================================="
echo "   SETUP RASPBERRY PI 4 – SERVER MASTER  "
echo " homeassistant,unifi,uisp,portainer,cockpit"
echo "========================================="

# Atualização do sistema
echo "[1/10] Atualizando sistema..."
sudo apt update && sudo apt upgrade -y

# --------------------------------------------------------------------
# Instalar Docker
# --------------------------------------------------------------------
echo "[2/10] Instalando Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Habilitar serviço
sudo systemctl enable docker
sudo systemctl start docker

# Instalar Docker Compose
echo "[3/10] Instalando Docker Compose..."
sudo apt install -y python3-pip
sudo pip3 install docker-compose

# Criar pasta de serviços
echo "[4/10] Criando estrutura de pastas..."
mkdir -p ~/server-rpi4/{homeassistant,unifi,uisp,portainer,cockpit}

cd ~/server-rpi4

# --------------------------------------------------------------------
# Docker Compose – Contêineres do Raspberry Pi 4
# --------------------------------------------------------------------
echo "[5/10] Gerando docker-compose.yml..."

cat << 'EOF' > docker-compose.yml
version: "3.9"

services:

  # --------------------------
  # Home Assistant + HACS
  # --------------------------
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    restart: unless-stopped
    network_mode: host
    privileged: true
    volumes:
      - ./homeassistant:/config
      - /etc/localtime:/etc/localtime:ro

  # --------------------------
  # Unifi Network Controller
  # --------------------------
  unifi:
    container_name: unifi-controller
    image: linuxserver/unifi-controller:latest
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./unifi:/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo

  # --------------------------
  # UISP
  # --------------------------
  uisp:
    container_name: uisp
    image: ghcr.io/ubiquiti/uisp:latest
    restart: unless-stopped
    ports:
      - 5080:80
      - 5443:443
    volumes:
      - ./uisp:/data

  # --------------------------
  # Portainer
  # --------------------------
  portainer:
    container_name: portainer
    image: portainer/portainer-ce:latest
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer:/data

  # --------------------------
  # Cockpit (somente sistema, fora do Docker)
  # --------------------------
EOF

# --------------------------------------------------------------------
# Instalar Cockpit nativo (não em container)
# --------------------------------------------------------------------
echo "[6/10] Instalando Cockpit..."
sudo apt install -y cockpit cockpit-pcp
sudo systemctl enable cockpit
sudo systemctl start cockpit

# --------------------------------------------------------------------
# Otimizações do sistema
# --------------------------------------------------------------------
echo "[7/10] Otimizando consumo de RAM..."

# Desabilitar serviços desnecessários
sudo systemctl disable triggerhappy.service --now 2>/dev/null || true
sudo systemctl disable bluetooth.service --now 2>/dev/null || true
sudo systemctl disable avahi-daemon.service --now 2>/dev/null || true

# Ajustar swap para evitar desgaste
echo "[8/10] Ajustando swap..."
sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
sudo systemctl restart dphys-swapfile

# --------------------------------------------------------------------
# Finalização
# --------------------------------------------------------------------
echo "[9/10] Subindo containers..."
docker-compose up -d

echo "[10/10] Finalizado!"
echo "----------------------------------------"
echo " ACESSE OS SERVIÇOS:"
echo " Home Assistant: http://<IP>:8123"
echo " Portainer:      http://<IP>:9000"
echo " Unifi:          https://<IP>:8443"
echo " UISP:           https://<IP>:5443"
echo " Cockpit:        https://<IP>:9090"
echo "----------------------------------------"
echo "REINICIE O RASPBERRY PI PARA FINALIZAR."
echo "========================================="
