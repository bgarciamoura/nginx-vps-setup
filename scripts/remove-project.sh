#!/bin/bash

# Script para remover projeto do Nginx VPS Setup
# Remove de forma segura: containers, configs, volumes (opcional)

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

print_header "Remover Projeto"

# Verificar se foi passado nome do projeto como argumento
if [ -n "$1" ]; then
    PROJECT_NAME=$1
else
    # Listar projetos disponíveis
    echo "Projetos disponíveis:"
    echo ""
    for dir in "$PROJECT_ROOT/projects"/*; do
        if [ -d "$dir" ] && [ "$(basename "$dir")" != "templates" ]; then
            echo "  - $(basename "$dir")"
        fi
    done
    echo ""

    echo -n "Nome do projeto para remover: "
    read PROJECT_NAME
fi

if [ -z "$PROJECT_NAME" ]; then
    print_error "Nome do projeto não pode ser vazio"
    exit 1
fi

# Verificar se projeto existe
PROJECT_DIR="$PROJECT_ROOT/projects/$PROJECT_NAME"
NGINX_CONF="$PROJECT_ROOT/nginx/conf.d/$PROJECT_NAME.conf"

if [ ! -d "$PROJECT_DIR" ] && [ ! -f "$NGINX_CONF" ]; then
    print_error "Projeto '$PROJECT_NAME' não encontrado"
    print_info "Diretório: $PROJECT_DIR"
    print_info "Config Nginx: $NGINX_CONF"
    exit 1
fi

# Resumo do que será removido
print_header "Resumo da Remoção"

echo "Projeto: $PROJECT_NAME"
echo ""
echo "Será removido:"

if [ -d "$PROJECT_DIR" ]; then
    echo "  ✓ Diretório: $PROJECT_DIR"
fi

if [ -f "$NGINX_CONF" ]; then
    echo "  ✓ Config Nginx: $NGINX_CONF"
fi

# Verificar se há containers rodando
if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
    CONTAINERS=$(docker compose -f "$PROJECT_DIR/docker-compose.yml" ps -q 2>/dev/null || true)
    if [ -n "$CONTAINERS" ]; then
        echo "  ✓ Containers Docker (serão parados)"
    fi
fi

echo ""
print_warning "ATENÇÃO: Esta ação não pode ser desfeita!"
echo ""
echo -n "Deseja remover volumes/dados também? (s/N): "
read REMOVE_VOLUMES

echo ""
echo -n "Confirma a remoção? (s/N): "
read CONFIRM

if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    print_info "Operação cancelada"
    exit 0
fi

echo ""
print_info "Iniciando remoção..."

# 1. Parar e remover containers
if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
    print_info "Parando containers..."

    if [[ "$REMOVE_VOLUMES" =~ ^[sS]$ ]]; then
        # Remover com volumes
        docker compose -f "$PROJECT_DIR/docker-compose.yml" down -v 2>/dev/null || true
        print_success "Containers e volumes removidos"
    else
        # Remover sem volumes (preservar dados)
        docker compose -f "$PROJECT_DIR/docker-compose.yml" down 2>/dev/null || true
        print_success "Containers removidos (volumes preservados)"
    fi
fi

# 2. Remover configuração Nginx
if [ -f "$NGINX_CONF" ]; then
    print_info "Removendo configuração Nginx..."
    rm -f "$NGINX_CONF"
    print_success "Configuração Nginx removida"
fi

# 3. Testar e reload Nginx
print_info "Recarregando Nginx..."
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec nginx nginx -t &>/dev/null; then
    docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec nginx nginx -s reload
    print_success "Nginx recarregado"
else
    print_warning "Erro ao testar configuração Nginx"
fi

# 4. Remover diretório do projeto
if [ -d "$PROJECT_DIR" ]; then
    print_info "Removendo diretório do projeto..."
    rm -rf "$PROJECT_DIR"
    print_success "Diretório removido"
fi

# 5. Verificar certificados SSL órfãos
print_info "Verificando certificados SSL..."
SSL_DOMAIN=$(grep -r "server_name.*$PROJECT_NAME" "$PROJECT_ROOT/nginx/conf.d/" 2>/dev/null | grep -oP 'server_name\s+\K[^;]+' | head -1 || true)

if [ -n "$SSL_DOMAIN" ]; then
    echo ""
    print_warning "Certificado SSL encontrado para: $SSL_DOMAIN"
    echo -n "Deseja remover o certificado SSL também? (s/N): "
    read REMOVE_SSL

    if [[ "$REMOVE_SSL" =~ ^[sS]$ ]]; then
        print_info "Removendo certificado SSL..."
        docker compose -f "$PROJECT_ROOT/docker-compose.yml" run --rm certbot delete --cert-name "$SSL_DOMAIN" 2>/dev/null || true
        print_success "Certificado SSL removido"
    else
        print_info "Certificado SSL preservado"
    fi
fi

# Resumo final
print_header "Remoção Concluída!"

echo ""
print_success "Projeto '$PROJECT_NAME' removido com sucesso!"
echo ""

if [[ ! "$REMOVE_VOLUMES" =~ ^[sS]$ ]]; then
    print_info "Volumes Docker foram preservados."
    print_info "Para listar: docker volume ls"
    print_info "Para remover manualmente: docker volume rm <volume-name>"
    echo ""
fi

print_info "Para adicionar um novo projeto:"
echo "  ./scripts/add-project.sh"
echo ""
