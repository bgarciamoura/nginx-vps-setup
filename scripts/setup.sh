#!/bin/bash

# Script de Setup Inicial da VPS
# Este script prepara a VPS para rodar o nginx-vps-setup

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções auxiliares
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    print_error "Este script precisa ser executado como root"
    print_info "Execute: sudo ./scripts/setup.sh"
    exit 1
fi

print_header "Nginx VPS Setup - Configuração Inicial"

# 1. Atualizar sistema
print_info "Atualizando sistema operacional..."
apt-get update -qq
apt-get upgrade -y -qq
print_success "Sistema atualizado"

# 2. Instalar dependências
print_info "Instalando dependências necessárias..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    ufw \
    fail2ban \
    logrotate \
    ca-certificates \
    gnupg \
    lsb-release
print_success "Dependências instaladas"

# 3. Instalar Docker (se não estiver instalado)
if ! command -v docker &> /dev/null; then
    print_info "Docker não encontrado. Instalando Docker..."

    # Adicionar repositório Docker
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Iniciar e habilitar Docker
    systemctl start docker
    systemctl enable docker

    print_success "Docker instalado"
else
    print_success "Docker já instalado: $(docker --version)"
fi

# 4. Configurar Firewall (UFW)
print_info "Configurando firewall (UFW)..."

# Garantir que SSH não será bloqueado
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Habilitar UFW (se não estiver habilitado)
if ! ufw status | grep -q "Status: active"; then
    print_warning "Habilitando UFW. Certifique-se de que a porta SSH (22) está permitida!"
    echo "y" | ufw enable
fi

ufw reload
print_success "Firewall configurado"

# 5. Configurar Fail2Ban
print_info "Configurando Fail2Ban..."

# Criar configuração customizada
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
findtime = 600
bantime = 3600
EOF

systemctl enable fail2ban
systemctl restart fail2ban
print_success "Fail2Ban configurado"

# 6. Criar rede Docker
print_info "Criando rede Docker (proxy-network)..."
if docker network inspect proxy-network &>/dev/null; then
    print_warning "Rede proxy-network já existe"
else
    docker network create proxy-network
    print_success "Rede proxy-network criada"
fi

# 7. Configurar Logrotate para Nginx
print_info "Configurando rotação de logs..."

cat > /etc/logrotate.d/nginx-vps <<EOF
/var/lib/docker/volumes/nginx-logs/_data/*.log {
    daily
    rotate 14
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        docker compose exec nginx nginx -s reopen 2>/dev/null || true
    endscript
}
EOF

print_success "Logrotate configurado"

# 8. Copiar arquivo .env se não existir
if [ ! -f .env ]; then
    print_info "Criando arquivo .env..."
    cp .env.example .env
    print_warning "IMPORTANTE: Edite o arquivo .env com suas configurações!"
    print_info "Execute: nano .env"
fi

# 9. Subir containers Nginx + Certbot
print_info "Iniciando containers Nginx + Certbot..."
docker compose up -d

# Aguardar containers ficarem saudáveis
print_info "Aguardando containers ficarem saudáveis..."
sleep 10

if docker compose ps | grep -q "healthy\|running"; then
    print_success "Containers iniciados com sucesso"
else
    print_error "Erro ao iniciar containers. Verifique com: docker compose logs"
fi

# 10. Configurar Crontab para renovação SSL e backup
print_info "Configurando tarefas agendadas (crontab)..."

# Verificar se já existe crontab
CRON_TEMP=$(mktemp)
crontab -l > "$CRON_TEMP" 2>/dev/null || true

# Renovação SSL (2x por dia)
if ! grep -q "certbot renew" "$CRON_TEMP"; then
    echo "30 2,14 * * * cd $(pwd) && docker compose run --rm certbot renew --quiet && docker compose exec nginx nginx -s reload" >> "$CRON_TEMP"
    print_info "Adicionada tarefa: Renovação SSL"
fi

# Backup diário
if ! grep -q "backup-configs.sh" "$CRON_TEMP"; then
    echo "0 3 * * * cd $(pwd) && ./scripts/backup-configs.sh" >> "$CRON_TEMP"
    print_info "Adicionada tarefa: Backup diário"
fi

crontab "$CRON_TEMP"
rm "$CRON_TEMP"
print_success "Tarefas agendadas configuradas"

# 11. Criar diretório de backups
mkdir -p backups
print_success "Diretório de backups criado"

# 12. Configurar permissões dos scripts
chmod +x scripts/*.sh
print_success "Permissões dos scripts configuradas"

# Resumo final
print_header "Setup Concluído!"

echo ""
print_success "VPS configurada com sucesso!"
echo ""
print_info "Próximos passos:"
echo "  1. Edite o arquivo .env com suas configurações:"
echo "     nano .env"
echo ""
echo "  2. Adicione seu primeiro projeto:"
echo "     ./scripts/add-project.sh"
echo ""
echo "  3. Ou manualmente:"
echo "     - Copie um template de projects/templates/"
echo "     - Configure nginx/conf.d/seu-projeto.conf"
echo "     - Obtenha SSL: ./scripts/get-ssl.sh seu-dominio.com"
echo "     - Deploy: docker compose -f projects/seu-projeto/docker-compose.yml up -d"
echo ""
print_info "Verificar status:"
echo "  - Containers: docker compose ps"
echo "  - Logs Nginx: docker compose logs nginx"
echo "  - Firewall: ufw status"
echo "  - Fail2Ban: fail2ban-client status"
echo ""
print_warning "IMPORTANTE: Certifique-se de que seus domínios estão apontando para este servidor!"
echo ""
