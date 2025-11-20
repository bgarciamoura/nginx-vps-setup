#!/bin/bash

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   VPS Nginx Manager - Setup Inicial     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Verificar se .env existe
if [ ! -f .env ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
    echo -e "${YELLOW}Copie o .env.example e configure suas variáveis:${NC}"
    echo -e "   cp .env.example .env"
    echo -e "   nano .env"
    exit 1
fi

# Carregar variáveis do .env
source .env

# Validar variáveis obrigatórias
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}❌ Configure DOMAIN e EMAIL no arquivo .env${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Configurações:${NC}"
echo -e "   Domínio: ${GREEN}$DOMAIN${NC}"
echo -e "   Email: ${GREEN}$EMAIL${NC}"
echo -e "   Wildcard SSL: ${GREEN}$USE_WILDCARD_SSL${NC}"
echo ""

# Confirmar
read -p "Deseja continuar com estas configurações? (s/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo -e "${YELLOW}Setup cancelado.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}🔧 Criando estrutura de diretórios...${NC}"

# Criar diretórios
mkdir -p nginx-proxy/nginx/conf.d
mkdir -p nginx-proxy/certbot/conf
mkdir -p nginx-proxy/certbot/www
mkdir -p nginx-proxy/ssl
mkdir -p projects

echo -e "${GREEN}✅ Estrutura de diretórios criada${NC}"

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker não encontrado!${NC}"
    echo -e "${YELLOW}Instale o Docker primeiro: https://docs.docker.com/engine/install/${NC}"
    exit 1
fi

# Verificar se Docker Compose está instalado
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose não encontrado!${NC}"
    echo -e "${YELLOW}Instale o Docker Compose primeiro${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker e Docker Compose encontrados${NC}"

# Criar rede proxy-network se não existir
echo -e "${YELLOW}🌐 Configurando rede Docker...${NC}"
if ! docker network ls | grep -q proxy-network; then
    docker network create proxy-network
    echo -e "${GREEN}✅ Rede proxy-network criada${NC}"
else
    echo -e "${GREEN}✅ Rede proxy-network já existe${NC}"
fi

# Criar configuração inicial do Nginx (health check)
echo -e "${YELLOW}📝 Criando configuração inicial do Nginx...${NC}"
cat > nginx-proxy/nginx/conf.d/00-default.conf <<EOF
# Health check endpoint
server {
    listen 80 default_server;
    server_name _;
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 404;
    }
}
EOF

echo -e "${GREEN}✅ Configuração inicial criada${NC}"

# Subir Nginx Proxy
echo -e "${YELLOW}🚀 Iniciando Nginx Proxy...${NC}"
cd nginx-proxy
docker-compose up -d
cd ..

echo -e "${GREEN}✅ Nginx Proxy iniciado${NC}"

# Aguardar Nginx iniciar
echo -e "${YELLOW}⏳ Aguardando Nginx inicializar...${NC}"
sleep 5

# Verificar se Nginx está rodando
if ! docker ps | grep -q nginx-proxy; then
    echo -e "${RED}❌ Nginx não está rodando!${NC}"
    echo -e "${YELLOW}Verifique os logs: docker logs nginx-proxy${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Nginx está rodando${NC}"

# Configurar SSL
if [ "$USE_WILDCARD_SSL" = "true" ]; then
    echo ""
    echo -e "${YELLOW}🔐 Configurando certificado SSL Wildcard...${NC}"
    echo -e "${YELLOW}⚠️  Você precisará adicionar um registro TXT no DNS${NC}"
    echo ""
    
    # Gerar certificado wildcard
    docker exec -it certbot certbot certonly \
        --manual \
        --preferred-challenges dns \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "*.$DOMAIN" \
        -d "$DOMAIN"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Certificado wildcard gerado com sucesso!${NC}"
    else
        echo -e "${YELLOW}⚠️  Não foi possível gerar o certificado wildcard${NC}"
        echo -e "${YELLOW}   Você pode gerá-lo manualmente depois com:${NC}"
        echo -e "   docker exec -it certbot certbot certonly --manual --preferred-challenges dns -d \"*.$DOMAIN\" -d \"$DOMAIN\""
    fi
else
    echo -e "${YELLOW}ℹ️  Certificados SSL serão gerados individualmente para cada projeto${NC}"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✅ Setup concluído!               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📚 Próximos passos:${NC}"
echo ""
echo -e "1. Adicionar um novo projeto:"
echo -e "   ${GREEN}./scripts/add-project.sh${NC}"
echo ""
echo -e "2. Listar projetos:"
echo -e "   ${GREEN}./scripts/list-projects.sh${NC}"
echo ""
echo -e "3. Ver logs do Nginx:"
echo -e "   ${GREEN}docker logs nginx-proxy -f${NC}"
echo ""
echo -e "${YELLOW}📖 Para mais informações, consulte o README.md${NC}"
echo ""
