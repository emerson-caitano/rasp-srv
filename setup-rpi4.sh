#!/bin/bash

# =====================
# Funções de cores
# =====================
GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

header() {
    echo -e "${CYAN}"
    echo "==============================================="
    echo "  $1"
    echo "==============================================="
    echo -e "${RESET}"
}

# =====================
# INÍCIO DO SCRIPT
# =====================

header "ATUALIZANDO SISTEMA"
sudo apt update && sudo apt upgrade -y

header "INSTALANDO DEPENDÊNCIAS BÁSICAS"
sudo apt install -y git curl software-properties-common \
    docker.io docker-compose python3-venv python3-full

header "HABILITANDO DOCKER"
sudo systemctl enable docker
sudo systemctl start docker

header "INSTALANDO PORTAINER VIA DOCKER"
sudo docker volume create portainer_data
sudo docker run -d \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

header "INSTALANDO COCKPIT"
sudo apt install -y cockpit

header "INSTALANDO HOME ASSISTANT (CONTAINER)"
sudo docker run -d \
  --name homeassistant \
  --privileged \
  --restart=unless-stopped \
  -e TZ="America/Sao_Paulo" \
  -v /home/pi/homeassistant:/config \
  -p 8123:8123 \
  ghcr.io/home-assistant/home-assistant:stable

header "INSTALANDO UNIFI NETWORK CONTROLLER"
sudo docker run -d \
  --name unifi \
  --restart=unless-stopped \
  -p 8443:8443 \
  -p 3478:3478/udp \
  -p 10001:10001/udp \
  -v /home/pi/unifi:/unifi \
  jacobalberty/unifi:latest

header "INSTALANDO UISP"
sudo docker run -d \
  --name uisp \
  --restart=unless-stopped \
  -p 8080:80 \
  -p 9444:443 \
  -v /home/pi/uisp:/config \
  ghcr.io/uisp/uisp:latest

header "FINALIZADO! 🎉"
echo -e "${GREEN}Todos os serviços foram instalados com sucesso no Raspberry Pi 4!${RESET}"
echo ""
echo -e "${YELLOW}Portainer:${RESET} https://IP_DO_RPI:9443"
echo -e "${YELLOW}Home Assistant:${RESET} http://IP_DO_RPI:8123"
echo -e "${YELLOW}Cockpit:${RESET} http://IP_DO_RPI:9090"
echo -e "${YELLOW}Unifi Controller:${RESET} https://IP_DO_RPI:8443"
echo -e "${YELLOW}UISP:${RESET} https://IP_DO_RPI:9444"
