#!/bin/bash
set -euo pipefail

echo "========================================="
echo "   SETUP RASPBERRY PI 4 – SERVER MASTER  "
echo "========================================="

# 0) exigir execução como root (ou via sudo)
if [ "$EUID" -ne 0 ]; then
  echo "Por favor rode o script com sudo: sudo ./setup-rpi4.sh"
  exit 1
fi

# 1) Atualização do sistema
echo "[1/12] Atualizando sistema..."
apt update -y
apt upgrade -y

# 2) Instalar dependências básicas
echo "[2/12] Instalando pacotes básicos..."
apt install -y \
  ca-certificates curl gnupg lsb-release software-properties-common \
  apt-transport-https dirmngr git

# 3) Instalar Docker (script oficial)
echo "[3/12] Instalando Docker..."
curl -fsSL https://get.docker.com | sh

# Garantir que o usuário pi (ou outro) tenha permissão — usamos $SUDO_USER se disponível
TARGET_USER="${SUDO_USER:-pi}"
usermod -aG docker "$TARGET_USER" 2>/dev/null || true

systemctl enable docker
systemctl start docker

# 4) Instalar Docker Compose v2 (plugin oficial via apt) - preferível ao pip
echo "[4/12] Instalando docker compose (plugin)..."
# Em Debian/Raspberry, o pacote chama docker-compose-plugin - usar apt
apt update -y
apt install -y docker-compose-plugin

# verificar: 'docker compose version'
echo "[OK] docker compose version:"
docker compose version || echo "Aviso: docker compose não retornou versão (verifique instalação)."

# 5) Instalar Python venv (para pip seguro) caso precise
echo "[5/12] Instalando python (venv) para ambientes virtuais..."
apt install -y python3-full python3-venv

# 6) Criar estrutura de pastas
echo "[6/12] Criando estrutura de pastas em /opt/server-rpi4..."
mkdir -p /opt/server-rpi4/{homeassistant,unifi,uisp,portainer,cockpit}
chown -R "$TARGET_USER":"$TARGET_USER" /opt/server-rpi4
cd /opt/server-rpi4

# 7) Gerar docker-compose.yml (ajuste mínimo; confirme imagens ARM quando necessário)
echo "[7/12] Gerando docker-compose.yml..."
cat > docker-compose.yml <<'EOF'
version: "3.9"
services:

  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    restart: unless-stopped
    network_mode: host
    privileged: true
    volumes:
      - ./homeassistant:/config
      - /etc/localtime:/etc/localtime:ro

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

  uisp:
    container_name: uisp
    image: ghcr.io/ubiquiti/uisp:latest
    restart: unless-stopped
    ports:
      - 5080:80
      - 5443:443
    volumes:
      - ./uisp:/data

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

# Observação: Cockpit será instalado nativamente (fora do Docker)
EOF

# 8) Instalar Cockpit (nativo)
echo "[8/12] Instalando Cockpit (nativo)..."
apt install -y cockpit
systemctl enable --now cockpit

# 9) Otimizações do sistema (desabilitar serviços desnecessários)
echo "[9/12] Desabilitando serviços opcionais..."
systemctl disable triggerhappy.service --now 2>/dev/null || true
systemctl disable bluetooth.service --now 2>/dev/null || true
systemctl disable avahi-daemon.service --now 2>/dev/null || true

# 10) Ajustar swap para estabilidade (1GB)
echo "[10/12] Ajustando swap para 1024MB..."
apt install -y dphys-swapfile
sed -i 's/^\s*CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile || echo "CONF_SWAPSIZE=1024" >> /etc/dphys-swapfile
systemctl restart dphys-swapfile

# 11) Subir containers com docker compose (plugin)
echo "[11/12] Subindo containers (docker compose up -d)..."
# executar como o usuário alvo para criar os volumes com a UID correta
sudo -u "$TARGET_USER" docker compose up -d

# 12) Finalização / instruções
echo "[12/12] Finalizado! Resumo de acesso:"
echo " Home Assistant:  http://<IP>:8123  (rodando em network host)"
echo " Portainer:       http://<IP>:9000"
echo " Unifi:           https://<IP>:8443  (Unifi usa network host)"
echo " UISP:            https://<IP>:5443"
echo " Cockpit:         https://<IP>:9090"
echo ""
echo "Recomendo: rebootar o sistema agora: sudo reboot"
echo "Se precisar instalar pacotes Python, use ambientes virtuais:"
echo "  python3 -m venv ~/venv && source ~/venv/bin/activate && pip install <pkg>"

exit 0
