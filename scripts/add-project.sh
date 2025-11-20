#!/bin/bash

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Adicionar Novo Projeto               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Carregar variáveis do .env
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
    exit 1
fi

# Parâmetros via argumentos ou interativo
if [ $# -eq 4 ]; then
    SUBDOMAIN=$1
    CONTAINER_NAME=$2
    PORT=$3
    REPLICAS=$4
else
    # Modo interativo
    read -p "Digite o nome do subdomínio (ex: api): " SUBDOMAIN
    read -p "Digite o nome base do container (ex: api-app): " CONTAINER_NAME
    read -p "Digite a porta interna do container (ex: 4000): " PORT
    read -p "Quantas réplicas para load balancing? (1-10, padrão 1): " REPLICAS
    REPLICAS=${REPLICAS:-1}
fi

# Validações
if [ -z "$SUBDOMAIN" ] || [ -z "$CONTAINER_NAME" ] || [ -z "$PORT" ]; then
    echo -e "${RED}❌ Todos os parâmetros são obrigatórios!${NC}"
    echo -e "${YELLOW}Uso: ./add-project.sh <subdomain> <container-name> <port> <replicas>${NC}"
    exit 1
fi

if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]] || [ "$REPLICAS" -lt 1 ] || [ "$REPLICAS" -gt 10 ]; then
    echo -e "${RED}❌ Número de réplicas deve ser entre 1 e 10${NC}"
    exit 1
fi

FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
PROJECT_DIR="projects/${SUBDOMAIN}"
NGINX_CONFIG="nginx-proxy/nginx/conf.d/${SUBDOMAIN}.conf"

echo ""
echo -e "${YELLOW}📋 Resumo do projeto:${NC}"
echo -e "   Subdomínio: ${GREEN}${FULL_DOMAIN}${NC}"
echo -e "   Container: ${GREEN}${CONTAINER_NAME}${NC}"
echo -e "   Porta: ${GREEN}${PORT}${NC}"
echo -e "   Réplicas: ${GREEN}${REPLICAS}${NC}"
echo ""

# Verificar se projeto já existe
if [ -f "$NGINX_CONFIG" ]; then
    echo -e "${RED}❌ Projeto já existe: ${SUBDOMAIN}${NC}"
    exit 1
fi

read -p "Confirma a criação deste projeto? (s/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo -e "${YELLOW}Operação cancelada.${NC}"
    exit 0
fi

# Criar diretório do projeto
echo -e "${YELLOW}📁 Criando diretório do projeto...${NC}"
mkdir -p "$PROJECT_DIR"

# Criar configuração do Nginx
echo -e "${YELLOW}📝 Criando configuração do Nginx...${NC}"

# Gerar upstream com réplicas
UPSTREAM=""
if [ "$REPLICAS" -gt 1 ]; then
    UPSTREAM="upstream ${SUBDOMAIN}_backend {\n"
    UPSTREAM+="    least_conn;\n"
    for i in $(seq 1 $REPLICAS); do
        UPSTREAM+="    server ${CONTAINER_NAME}-${i}:${PORT};\n"
    done
    UPSTREAM+="}\n\n"
    BACKEND_TARGET="${SUBDOMAIN}_backend"
else
    UPSTREAM=""
    BACKEND_TARGET="${CONTAINER_NAME}:${PORT}"
fi

# Determinar caminho do certificado
if [ "$USE_WILDCARD_SSL" = "true" ]; then
    SSL_CERT="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
    SSL_KEY="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
else
    SSL_CERT="/etc/letsencrypt/live/${FULL_DOMAIN}/fullchain.pem"
    SSL_KEY="/etc/letsencrypt/live/${FULL_DOMAIN}/privkey.pem"
fi

# Criar arquivo de configuração
cat > "$NGINX_CONFIG" <<EOF
${UPSTREAM}server {
    listen 80;
    server_name ${FULL_DOMAIN};
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${FULL_DOMAIN};
    
    ssl_certificate ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Logging
    access_log /var/log/nginx/${SUBDOMAIN}_access.log;
    error_log /var/log/nginx/${SUBDOMAIN}_error.log;
    
    location / {
        proxy_pass http://${BACKEND_TARGET};
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        
        # Proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

echo -e "${GREEN}✅ Configuração do Nginx criada${NC}"

# Criar docker-compose.yml do projeto
echo -e "${YELLOW}📝 Criando docker-compose.yml...${NC}"

if [ "$REPLICAS" -gt 1 ]; then
    # Múltiplas réplicas
    SERVICES=""
    for i in $(seq 1 $REPLICAS); do
        SERVICES+="  ${CONTAINER_NAME}-${i}:\n"
        SERVICES+="    image: nginx:alpine  # SUBSTITUA pela sua imagem\n"
        SERVICES+="    container_name: ${CONTAINER_NAME}-${i}\n"
        SERVICES+="    restart: unless-stopped\n"
        SERVICES+="    environment:\n"
        SERVICES+="      - PORT=${PORT}\n"
        SERVICES+="    networks:\n"
        SERVICES+="      - proxy-network\n"
        if [ $i -lt $REPLICAS ]; then
            SERVICES+="\n"
        fi
    done
    
    cat > "${PROJECT_DIR}/docker-compose.yml" <<EOF
version: '3.8'

services:
$(echo -e "$SERVICES")

networks:
  proxy-network:
    external: true
EOF
else
    # Réplica única
    cat > "${PROJECT_DIR}/docker-compose.yml" <<EOF
version: '3.8'

services:
  app:
    image: nginx:alpine  # SUBSTITUA pela sua imagem
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    environment:
      - PORT=${PORT}
    networks:
      - proxy-network

networks:
  proxy-network:
    external: true
EOF
fi

echo -e "${GREEN}✅ Docker Compose criado${NC}"

# Criar README do projeto
cat > "${PROJECT_DIR}/README.md" <<EOF
# ${SUBDOMAIN}

Projeto criado em $(date)

## Configurações

- **URL**: https://${FULL_DOMAIN}
- **Porta interna**: ${PORT}
- **Réplicas**: ${REPLICAS}

## Comandos

### Subir o projeto
\`\`\`bash
docker-compose up -d
\`\`\`

### Ver logs
\`\`\`bash
docker-compose logs -f
\`\`\`

### Parar o projeto
\`\`\`bash
docker-compose down
\`\`\`

### Rebuild
\`\`\`bash
docker-compose up -d --build
\`\`\`

## Notas

Edite o \`docker-compose.yml\` e substitua \`nginx:alpine\` pela imagem do seu projeto.
EOF

# Verificar/Gerar certificado SSL se necessário
if [ "$USE_WILDCARD_SSL" != "true" ]; then
    echo ""
    echo -e "${YELLOW}🔐 Gerando certificado SSL...${NC}"
    
    # Primeiro recarregar nginx para validação ACME funcionar
    docker exec nginx-proxy nginx -s reload
    sleep 2
    
    docker exec certbot certbot certonly --webroot \
        --webroot-path /var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "${FULL_DOMAIN}" || {
        echo -e "${YELLOW}⚠️  Não foi possível gerar o certificado automaticamente${NC}"
        echo -e "${YELLOW}   Execute manualmente:${NC}"
        echo -e "   docker exec certbot certbot certonly --webroot --webroot-path /var/www/certbot -d ${FULL_DOMAIN}"
    }
fi

# Recarregar Nginx
echo -e "${YELLOW}🔄 Recarregando Nginx...${NC}"
docker exec nginx-proxy nginx -t && docker exec nginx-proxy nginx -s reload

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ Projeto criado com sucesso!      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📚 Próximos passos:${NC}"
echo ""
echo -e "1. Edite o docker-compose.yml do projeto:"
echo -e "   ${GREEN}nano ${PROJECT_DIR}/docker-compose.yml${NC}"
echo ""
echo -e "2. Adicione seu código ao diretório:"
echo -e "   ${GREEN}cd ${PROJECT_DIR}${NC}"
echo ""
echo -e "3. Suba o projeto:"
echo -e "   ${GREEN}docker-compose up -d${NC}"
echo ""
echo -e "4. Acesse o projeto:"
echo -e "   ${BLUE}https://${FULL_DOMAIN}${NC}"
echo ""
echo -e "${YELLOW}📖 Ver README do projeto: cat ${PROJECT_DIR}/README.md${NC}"
echo ""
