#!/bin/bash

# Script de deploy para projetos

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

# Obter diretório raiz
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Verificar argumento
if [ -z "$1" ]; then
    print_error "Uso: $0 nome-do-projeto"
    echo ""
    print_info "Projetos disponíveis:"
    ls -1 "$PROJECT_ROOT/projects" | grep -v "templates" || echo "  Nenhum projeto encontrado"
    exit 1
fi

PROJECT_NAME=$1
PROJECT_DIR="$PROJECT_ROOT/projects/$PROJECT_NAME"

# Verificar se projeto existe
if [ ! -d "$PROJECT_DIR" ]; then
    print_error "Projeto não encontrado: $PROJECT_NAME"
    print_info "Diretório esperado: $PROJECT_DIR"
    exit 1
fi

# Verificar se docker-compose.yml existe
if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
    print_error "docker-compose.yml não encontrado em: $PROJECT_DIR"
    exit 1
fi

print_header "Deploy: $PROJECT_NAME"

# Verificar se há arquivo .env no projeto
if [ -f "$PROJECT_DIR/.env" ]; then
    print_info "Usando variáveis de ambiente de: $PROJECT_DIR/.env"
fi

# Opções de deploy
echo "Opções de deploy:"
echo "  1) Build e deploy (reconstruir imagens)"
echo "  2) Deploy apenas (usar imagens existentes)"
echo "  3) Pull e deploy (baixar imagens do registry)"
echo "  4) Restart (reiniciar containers)"
echo "  5) Stop (parar containers)"
echo -n "Escolha (1-5): "
read DEPLOY_OPTION

cd "$PROJECT_DIR"

case $DEPLOY_OPTION in
    1)
        print_info "Fazendo build e deploy..."
        docker compose build
        docker compose up -d
        ;;
    2)
        print_info "Fazendo deploy..."
        docker compose up -d
        ;;
    3)
        print_info "Baixando imagens e fazendo deploy..."
        docker compose pull
        docker compose up -d
        ;;
    4)
        print_info "Reiniciando containers..."
        docker compose restart
        ;;
    5)
        print_info "Parando containers..."
        docker compose down
        print_success "Containers parados"
        exit 0
        ;;
    *)
        print_error "Opção inválida"
        exit 1
        ;;
esac

# Aguardar containers iniciarem
if [ "$DEPLOY_OPTION" != "5" ]; then
    print_info "Aguardando containers iniciarem..."
    sleep 5

    # Verificar status
    print_info "Status dos containers:"
    docker compose ps

    # Verificar se há containers unhealthy
    if docker compose ps | grep -q "unhealthy"; then
        print_warning "Há containers não saudáveis. Verifique os logs:"
        print_info "docker compose -f $PROJECT_DIR/docker-compose.yml logs"
    fi

    # Verificar logs recentes
    echo ""
    echo -n "Ver logs recentes? (s/N): "
    read VIEW_LOGS

    if [[ "$VIEW_LOGS" =~ ^[sS]$ ]]; then
        docker compose logs --tail=50
    fi

    print_header "Deploy Concluído"

    print_success "Projeto '$PROJECT_NAME' deployed!"
    echo ""
    print_info "Comandos úteis:"
    echo "  Ver logs: docker compose -f $PROJECT_DIR/docker-compose.yml logs -f"
    echo "  Status: docker compose -f $PROJECT_DIR/docker-compose.yml ps"
    echo "  Restart: docker compose -f $PROJECT_DIR/docker-compose.yml restart"
    echo "  Stop: docker compose -f $PROJECT_DIR/docker-compose.yml down"
    echo ""

    # Verificar se configuração Nginx existe
    NGINX_CONF="$PROJECT_ROOT/nginx/conf.d/$PROJECT_NAME.conf"
    if [ -f "$NGINX_CONF" ]; then
        print_success "Configuração Nginx: $NGINX_CONF"

        # Extrair domínio da configuração
        DOMAIN=$(grep "server_name" "$NGINX_CONF" | grep -v "#" | head -1 | awk '{print $2}' | tr -d ';')
        if [ ! -z "$DOMAIN" ] && [ "$DOMAIN" != "_" ]; then
            print_info "Acesse: https://$DOMAIN"
        fi
    else
        print_warning "Configuração Nginx não encontrada: $NGINX_CONF"
        print_info "Crie com: ./scripts/add-project.sh"
    fi
    echo ""
fi
