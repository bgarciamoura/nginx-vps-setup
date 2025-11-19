#!/bin/bash

# Script de backup das configurações do Nginx VPS Setup

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

# Obter diretório raiz
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Diretório de backups
BACKUP_DIR="$PROJECT_ROOT/backups"
mkdir -p "$BACKUP_DIR"

# Nome do backup com timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="nginx-vps-backup-$TIMESTAMP"
BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.tar.gz"

print_info "Iniciando backup das configurações..."

# Criar backup
tar -czf "$BACKUP_FILE" \
    -C "$PROJECT_ROOT" \
    --exclude='backups' \
    --exclude='logs' \
    --exclude='certbot' \
    --exclude='letsencrypt' \
    --exclude='projects/*/node_modules' \
    --exclude='projects/*/.git' \
    --exclude='projects/*/data' \
    --exclude='projects/*/volumes' \
    --exclude='.git' \
    --exclude='.env' \
    nginx/conf.d \
    nginx/nginx.conf \
    nginx/snippets \
    docker-compose.yml \
    .env.example \
    scripts \
    2>/dev/null

if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    print_success "Backup criado: $BACKUP_FILE ($BACKUP_SIZE)"
else
    print_error "Erro ao criar backup"
    exit 1
fi

# Backup dos volumes Docker (certificados)
print_info "Criando backup dos certificados SSL..."
CERT_BACKUP="$BACKUP_DIR/certbot-conf-$TIMESTAMP.tar.gz"

# Exportar volume certbot-conf
docker run --rm \
    -v certbot-conf:/data \
    -v "$BACKUP_DIR":/backup \
    alpine \
    tar -czf "/backup/certbot-conf-$TIMESTAMP.tar.gz" -C /data . \
    2>/dev/null

if [ $? -eq 0 ] && [ -f "$CERT_BACKUP" ]; then
    CERT_SIZE=$(du -h "$CERT_BACKUP" | cut -f1)
    print_success "Backup de certificados: $CERT_BACKUP ($CERT_SIZE)"
else
    print_warning "Não foi possível fazer backup dos certificados (volume pode não existir)"
fi

# Carregar configuração de retenção do .env
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Limpar backups antigos
print_info "Limpando backups com mais de $RETENTION_DAYS dias..."
find "$BACKUP_DIR" -name "nginx-vps-backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "certbot-conf-*.tar.gz" -mtime +$RETENTION_DAYS -delete
print_success "Backups antigos removidos"

# Listar backups existentes
echo ""
print_info "Backups disponíveis:"
ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

echo ""
print_success "Backup concluído!"
echo ""
print_info "Para restaurar:"
echo "  1. Extrair: tar -xzf $BACKUP_FILE -C /opt/vps-restore"
echo "  2. Copiar arquivos para o diretório correto"
echo "  3. Reload Nginx: docker compose exec nginx nginx -s reload"
echo ""
print_info "Para restaurar certificados:"
echo "  docker run --rm -v certbot-conf:/data -v $BACKUP_DIR:/backup alpine sh -c 'cd /data && tar -xzf /backup/certbot-conf-$TIMESTAMP.tar.gz'"
echo ""
