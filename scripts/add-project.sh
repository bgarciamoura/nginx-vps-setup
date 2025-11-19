#!/bin/bash

# Script para adicionar novo projeto ao Nginx VPS Setup
# Modo interativo com wizard

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

print_header "Adicionar Novo Projeto"

# 1. Nome do projeto
echo -n "Nome do projeto (ex: meu-app): "
read PROJECT_NAME

if [ -z "$PROJECT_NAME" ]; then
    print_error "Nome do projeto não pode ser vazio"
    exit 1
fi

# Validar nome (apenas letras, números, hífen e underscore)
if ! [[ "$PROJECT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    print_error "Nome inválido. Use apenas letras, números, hífen e underscore"
    exit 1
fi

# 2. Domínio
echo -n "Domínio (ex: app.dominio.com): "
read DOMAIN

if [ -z "$DOMAIN" ]; then
    print_error "Domínio não pode ser vazio"
    exit 1
fi

# 3. Porta interna
echo -n "Porta interna da aplicação (ex: 3000): "
read PORT

if [ -z "$PORT" ]; then
    print_error "Porta não pode ser vazia"
    exit 1
fi

# 4. Tipo de projeto
echo ""
echo "Tipo de projeto:"
echo "  1) Single Container (aplicação simples)"
echo "  2) Load Balanced (múltiplas réplicas)"
echo "  3) With Database (aplicação + banco de dados)"
echo -n "Escolha (1-3): "
read PROJECT_TYPE

case $PROJECT_TYPE in
    1)
        TEMPLATE="single-container"
        TEMPLATE_NAME="Single Container"
        ;;
    2)
        TEMPLATE="load-balanced"
        TEMPLATE_NAME="Load Balanced"
        ;;
    3)
        TEMPLATE="with-database"
        TEMPLATE_NAME="With Database"
        ;;
    *)
        print_error "Opção inválida"
        exit 1
        ;;
esac

# Resumo
print_header "Resumo"
echo "Nome do projeto: $PROJECT_NAME"
echo "Domínio: $DOMAIN"
echo "Porta: $PORT"
echo "Tipo: $TEMPLATE_NAME"
echo ""
echo -n "Confirma? (s/N): "
read CONFIRM

if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    print_info "Operação cancelada"
    exit 0
fi

# Criar diretório do projeto
PROJECT_DIR="$PROJECT_ROOT/projects/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    print_error "Projeto já existe: $PROJECT_DIR"
    exit 1
fi

print_info "Criando diretório do projeto..."
cp -r "$PROJECT_ROOT/projects/templates/$TEMPLATE" "$PROJECT_DIR"
print_success "Diretório criado: $PROJECT_DIR"

# Personalizar docker-compose.yml
print_info "Personalizando docker-compose.yml..."
if [ "$TEMPLATE" = "single-container" ]; then
    sed -i "s/meu-app/$PROJECT_NAME/g" "$PROJECT_DIR/docker-compose.yml"
    sed -i "s/PORT=3000/PORT=$PORT/g" "$PROJECT_DIR/docker-compose.yml"
elif [ "$TEMPLATE" = "load-balanced" ]; then
    sed -i "s/minha-api/$PROJECT_NAME/g" "$PROJECT_DIR/docker-compose.yml"
    sed -i "s/PORT=3000/PORT=$PORT/g" "$PROJECT_DIR/docker-compose.yml"
elif [ "$TEMPLATE" = "with-database" ]; then
    sed -i "s/meu-sistema/$PROJECT_NAME/g" "$PROJECT_DIR/docker-compose.yml"
    sed -i "s/PORT=3000/PORT=$PORT/g" "$PROJECT_DIR/docker-compose.yml"

    # Criar arquivo .env
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    sed -i "s/meu_sistema/${PROJECT_NAME}_db/g" "$PROJECT_DIR/.env"
    print_success "Arquivo .env criado: $PROJECT_DIR/.env"
    print_warning "IMPORTANTE: Edite $PROJECT_DIR/.env e configure senhas seguras!"
fi

# Criar configuração Nginx (APENAS HTTP inicialmente)
print_info "Criando configuração Nginx (HTTP)..."
NGINX_CONF="$PROJECT_ROOT/nginx/conf.d/$PROJECT_NAME.conf"

if [ -f "$NGINX_CONF" ]; then
    print_error "Configuração Nginx já existe: $NGINX_CONF"
    exit 1
fi

# Criar configuração inicial apenas com HTTP
cat > "$NGINX_CONF" <<EOF
# Configuração Nginx para $PROJECT_NAME
# HTTP (initial setup)

server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    # Proxy para aplicação
    location / {
        proxy_pass http://$PROJECT_NAME:$PORT;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

print_success "Configuração Nginx criada: $NGINX_CONF"

# Testar configuração Nginx
print_info "Testando configuração Nginx..."
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec nginx nginx -t &>/dev/null; then
    print_success "Configuração Nginx válida"
else
    print_error "Erro na configuração Nginx. Verifique: $NGINX_CONF"
    exit 1
fi

# Reload Nginx
print_info "Recarregando Nginx..."
docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec nginx nginx -s reload
print_success "Nginx recarregado"

# Obter certificado SSL
echo ""
echo -n "Obter certificado SSL agora? (s/N): "
read GET_SSL

if [[ "$GET_SSL" =~ ^[sS]$ ]]; then
    print_info "Obtendo certificado SSL para $DOMAIN..."
    if "$SCRIPT_DIR/get-ssl.sh" "$DOMAIN"; then
        print_success "Certificado SSL obtido!"

        # Agora atualizar configuração para incluir HTTPS
        print_info "Atualizando configuração Nginx para incluir HTTPS..."

        cat > "$NGINX_CONF" <<EOF
# Configuração Nginx para $PROJECT_NAME

# HTTP - Redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    # Redirect to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    # SSL Certificates
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # SSL parameters
    include /etc/nginx/snippets/ssl-params.conf;
    include /etc/nginx/snippets/security-headers.conf;

    # Logs
    access_log /var/log/nginx/$PROJECT_NAME-access.log main;
    error_log /var/log/nginx/$PROJECT_NAME-error.log warn;

    # Rate limiting
    limit_req zone=general burst=20 nodelay;
    limit_conn conn_limit 10;

    # Upload size
    client_max_body_size 50M;

    # Proxy para aplicação
    location / {
        proxy_pass http://$PROJECT_NAME:$PORT;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
EOF

        # Testar novamente
        if docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec nginx nginx -t &>/dev/null; then
            docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec nginx nginx -s reload
            print_success "Configuração HTTPS ativada!"
        else
            print_warning "Erro ao ativar HTTPS. Configuração HTTP mantida."
        fi
    else
        print_warning "Não foi possível obter certificado SSL."
        print_info "A configuração HTTP está ativa. Obtenha SSL depois com:"
        print_info "./scripts/get-ssl.sh $DOMAIN"
    fi
else
    print_warning "SSL não configurado. Site acessível apenas via HTTP."
    print_info "Para obter SSL depois: ./scripts/get-ssl.sh $DOMAIN"
fi

# Resumo final
print_header "Projeto Criado com Sucesso!"

echo ""
print_success "Projeto '$PROJECT_NAME' configurado!"
echo ""
print_info "Próximos passos:"
echo ""
echo "  1. Adicione seu código ao diretório:"
echo "     cd $PROJECT_DIR"
echo ""
echo "  2. Crie ou edite o Dockerfile (se necessário)"
echo ""
if [ "$TEMPLATE" = "with-database" ]; then
echo "  3. Configure as senhas do banco de dados:"
echo "     nano $PROJECT_DIR/.env"
echo ""
fi
echo "  4. Faça o deploy:"
echo "     ./scripts/deploy.sh $PROJECT_NAME"
echo ""
echo "     Ou manualmente:"
echo "     cd $PROJECT_DIR"
echo "     docker compose up -d --build"
echo ""
if [[ ! "$GET_SSL" =~ ^[sS]$ ]]; then
echo "  5. Obtenha certificado SSL:"
echo "     ./scripts/get-ssl.sh $DOMAIN"
echo ""
fi
print_info "Arquivos criados:"
echo "  - Projeto: $PROJECT_DIR"
echo "  - Nginx: $NGINX_CONF"
echo ""
print_info "Acesso:"
if [[ "$GET_SSL" =~ ^[sS]$ ]]; then
echo "  https://$DOMAIN"
else
echo "  http://$DOMAIN (HTTPS após obter SSL)"
fi
echo ""
print_info "Para verificar logs:"
echo "  docker compose -f $PROJECT_DIR/docker-compose.yml logs -f"
echo ""
