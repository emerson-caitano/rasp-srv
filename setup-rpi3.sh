#!/bin/bash

# ====================================================================
#  Raspberry Pi 3 – Setup de Serviços (NetAlertX, Pi-hole, Node-RED...)
#  Versão com cores, logs e estrutura igual ao script do RPi4
# ====================================================================

# ---------- CONFIGURAÇÃO DE CORES ----------
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

log() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

step() {
    echo -e "${BLUE}\n==================== $1 ====================${RESET}"
}

warn() {
    echo -e "${YELLOW}[AVISO]${RESET} $1"
}

error() {
    echo -e "${RED}[ERRO]${RESET} $1"
}

# ---------- INÍCIO ----------
step "1/10 - Atualizando o sistema"
sudo apt update && sudo apt upgrade -y
log "Sistema atualizado."

# ---------- SWAP ----------
step "2/10 - Configurando SWAP otimizado (2GB recomendado para Pi 3)"

sudo dphys-swapfile swapoff
sudo sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo systemctl restart dphys-swapfile

log "SWAP configurado com sucesso (2GB)."

# ---------- Docker ----------
step "3/10 - Instalando Docker"

curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
log "Docker instalado."

# ---------- Docker Compose ----------
step "4/10 - Instalando Docker Compose (plugin oficial)"

sudo apt install -y docker-compose-plugin
log "Docker Compose instalado."

# ---------- Pastas ----------
step "5/10 - Criando diretórios dos serviços"

sudo mkdir -p /opt/server-rpi3/netalertx
sudo mkdir -p /opt/server-rpi3/pihole
sudo mkdir -p /opt/server-rpi3/node-red
sudo mkdir -p /opt/server-rpi3/uptime-kuma

log "Pastas criadas."

# ---------- Cocker ----------
step "6/10 - Instalando Cockpit"

sudo apt install -y cockpit cockpit-networkmanager cockpit-packagekit
log "Cockpit instalado (porta 9090)."

# ---------- YAML ----------
step "7/10 - Criando arquivo docker-compose.yml"

cat << 'EOF' | sudo tee /opt/server-rpi3/docker-compose.yml
version: "3.9"

services:

  netalertx:
    image: jokobsk/netalertx:latest
    container_name: netalertx
    ports:
      - "20211:20211"
    volumes:
      - /opt/server-rpi3/netalertx:/app/data
    restart: unless-stopped

  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8081:80"
    environment:
      TZ: "America/Sao_Paulo"
      WEBPASSWORD: "admin"
    volumes:
      - /opt/server-rpi3/pihole/etc-pihole:/etc/pihole
      - /opt/server-rpi3/pihole/etc-dnsmasq.d:/etc/dnsmasq.d
    restart: unless-stopped
    cap_add:
      - NET_ADMIN

  node-red:
    image: nodered/node-red:latest
    container_name: node-red
    ports:
      - "1880:1880"
    volumes:
      - /opt/server-rpi3/node-red:/data
    restart: unless-stopped

  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    ports:
      - "3001:3001"
    volumes:
      - /opt/server-rpi3/uptime-kuma:/app/data
    restart: unless-stopped

EOF

log "docker-compose.yml criado."

# ---------- Permissões ----------
step "8/10 - Ajustando permissões"

sudo chown -R $USER:$USER /opt/server-rpi3
log "Permissões aplicadas."

# ---------- Docker UP ----------
step "9/10 - Subindo containers"

cd /opt/server-rpi3
docker compose up -d

log "Containers iniciados."

# ---------- Final ----------
step "10/10 - Concluído!"
echo -e "${GREEN}Todos os serviços foram instalados com sucesso!${RESET}"
echo -e "${BLUE}Acesse cada um:{RESET}"
echo -e "- Cockpit: http://<IP-do-RPi3>:9090"
echo -e "- NetAlertX: http://<IP-do-RPi3>:20211"
echo -e "- Pi-hole: http://<IP-do-RPi3>:8081"
echo -e "- Node-RED: http://<IP-do-RPi3>:1880"
echo -e "- Uptime Kuma: http://<IP-do-RPi3>:3001"
