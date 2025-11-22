#!/bin/bash

# ===============================
#   SCRIPT DE INSTALAÇÃO RPI4
#   Home Assistant, Unifi, UISP,
#   Portainer, Cockpit
# ===============================

# ----- Cores -----
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

banner() {
    echo -e "${CYAN}\n========================================"
    echo -e "  $1"
    echo -e "========================================${RESET}\n"
}

# ----- Verificar root -----
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${RESET}"
   exit 1
fi

banner "1/10 - Atualizando o sistema"
apt update && apt upgrade -y

banner "2/10 - Instalando dependências básicas"
apt install -y curl wget ca-certificates apt-transport-https software-properties-common gnupg lsb-release

banner "3/10 - Instalando Docker"
curl -fsSL https://get.docker.com | sh

banner "4/10 - Habilitando Docker"
systemctl enable docker
systemctl start docker

banner "5/10 - Instalando Docker Compose"
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64 \
    -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

banner "6/10 - Criando diretório dos serviços"
mkdir -p /opt/rpi4-server
cd /opt/rpi4-server

banner "7/10 - Gerando docker-compose.yml"

cat << 'EOF' > docker-compose.yml
services:

  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    network_mode: host
    privileged: true
    volumes:
      - ./homeassistant:/config
    restart: unless-stopped

  unifi:
    image: lscr.io/linuxserver/unifi-network-application:latest
    container_name: unifi
    networks:
      - unifi_net
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    volumes:
      - ./unifi:/config
    ports:
      - 8443:8443
      - 3478:3478/udp
      - 10001:10001/udp
    restart: unless-stopped

  uisp:
    image: nico640/docker-unms:latest
    container_name: uisp
    networks:
      - unifi_net
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./uisp:/data
    restart: unless-stopped

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    command: -H unix:///var/run/docker.sock
    ports:
      - 9000:9000
      - 9443:9443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer:/data
    restart: unless-stopped

networks:
  unifi_net:
    driver: bridge
EOF

banner "8/10 - Ajustando permissões"
chown -R $SUDO_USER:$SUDO_USER /opt/rpi4-server

banner "9/10 - Subindo containers"
docker-compose pull
docker-compose up -d

banner "10/10 - Instalação concluída!"
echo -e "${GREEN}Todos os serviços foram instalados com sucesso!${RESET}"

echo -e "${YELLOW}
Acesse:
- Home Assistant: http://IP_DO_PI:8123
- Unifi Network: https://IP_DO_PI:8443
- UISP (UNMS): https://IP_DO_PI/
- Portainer: https://IP_DO_PI:9443
${RESET}"

