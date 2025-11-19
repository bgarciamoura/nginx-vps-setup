#!/bin/bash

# Script para obter certificado SSL com Let's Encrypt (Certbot)

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Obter diretório raiz do projeto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Verificar argumento
if [ -z "$1" ]; then
    print_error "Uso: $0 dominio.com"
    exit 1
fi

DOMAIN=$1

# Carregar email do .env se existir
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Email para notificações (obrigatório para Let's Encrypt)
if [ -z "$SSL_EMAIL" ]; then
    echo -n "Email para notificações SSL: "
    read SSL_EMAIL

    if [ -z "$SSL_EMAIL" ]; then
        print_error "Email é obrigatório"
        exit 1
    fi
fi

print_header "Obter Certificado SSL"

print_info "Domínio: $DOMAIN"
print_info "Email: $SSL_EMAIL"
echo ""

# Verificar se domínio está apontando para este servidor
print_info "Verificando DNS..."
SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)

if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
    print_warning "ATENÇÃO: O domínio $DOMAIN não está apontando para este servidor!"
    print_info "IP do servidor: $SERVER_IP"
    print_info "IP do domínio: $DOMAIN_IP"
    echo ""
    echo -n "Continuar mesmo assim? (s/N): "
    read CONTINUE
    if [[ ! "$CONTINUE" =~ ^[sS]$ ]]; then
        print_info "Operação cancelada"
        exit 0
    fi
else
    print_success "DNS configurado corretamente"
fi

# Verificar se certificado já existe
print_info "Verificando certificado existente..."
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec certbot \
    certbot certificates -d $DOMAIN 2>&1 | grep -q "Certificate Name: $DOMAIN"; then
    print_warning "Certificado já existe para $DOMAIN"
    echo -n "Deseja renovar/recriar? (s/N): "
    read RENEW
    if [[ ! "$RENEW" =~ ^[sS]$ ]]; then
        print_info "Operação cancelada"
        exit 0
    fi
    FORCE_RENEWAL="--force-renewal"
else
    FORCE_RENEWAL=""
fi

# Solicitar certificado
print_info "Solicitando certificado SSL..."
echo ""

docker compose -f "$PROJECT_ROOT/docker-compose.yml" run --rm certbot \
    certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email $SSL_EMAIL \
    --agree-tos \
    --no-eff-email \
    $FORCE_RENEWAL \
    -d $DOMAIN

if [ $? -eq 0 ]; then
    print_success "Certificado obtido com sucesso!"
else
    print_error "Erro ao obter certificado"
    print_info "Possíveis causas:"
    echo "  - Domínio não está apontando para este servidor"
    echo "  - Portas 80/443 não estão acessíveis"
    echo "  - Firewall bloqueando acesso"
    echo "  - Nginx não está rodando"
    echo ""
    print_info "Para debug, execute:"
    echo "  docker compose logs nginx"
    echo "  docker compose logs certbot"
    exit 1
fi

# Atualizar configuração Nginx se necessário
NGINX_CONF="$PROJECT_ROOT/nginx/conf.d/*.conf"

print_info "Verificando configuração Nginx..."

# Verificar se há alguma configuração usando certificado temporário para este domínio
if grep -l "$DOMAIN" $NGINX_CONF | xargs grep -q "ssl_certificate.*default"; then
    print_warning "Configuração Nginx usa certificado temporário"
    print_info "Atualize o arquivo de configuração para usar o certificado real"
fi

# Testar configuração Nginx
print_info "Testando configuração Nginx..."
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec nginx nginx -t; then
    print_success "Configuração Nginx válida"
else
    print_error "Erro na configuração Nginx"
    print_warning "Verifique os arquivos em nginx/conf.d/"
    exit 1
fi

# Reload Nginx
print_info "Recarregando Nginx..."
docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec nginx nginx -s reload
print_success "Nginx recarregado"

# Verificar certificado
print_header "Certificado Instalado"

print_info "Verificando certificado..."
CERT_INFO=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec certbot \
    certbot certificates -d $DOMAIN 2>&1)

echo "$CERT_INFO" | grep -E "(Certificate Name|Expiry Date|Certificate Path)"

echo ""
print_success "Certificado SSL configurado para $DOMAIN"
echo ""
print_info "Teste o site:"
echo "  https://$DOMAIN"
echo ""
print_info "Verifique a nota SSL:"
echo "  https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo ""
print_info "O certificado será renovado automaticamente pelo cron"
print_info "Para renovar manualmente:"
echo "  docker compose run --rm certbot renew"
echo "  docker compose exec nginx nginx -s reload"
echo ""
