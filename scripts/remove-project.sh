#!/bin/bash

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Remover Projeto                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Carregar variáveis do .env
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
    exit 1
fi

# Verificar parâmetro
if [ -z "$1" ]; then
    echo -e "${RED}❌ Informe o nome do subdomínio do projeto${NC}"
    echo -e "${YELLOW}Uso: ./remove-project.sh <subdomain>${NC}"
    echo ""
    echo -e "${YELLOW}Projetos disponíveis:${NC}"
    if [ -d "nginx-proxy/nginx/conf.d" ]; then
        ls -1 nginx-proxy/nginx/conf.d/*.conf 2>/dev/null | sed 's/.*\///' | sed 's/\.conf$//' | grep -v "^00-default$" || echo "  Nenhum projeto encontrado"
    fi
    exit 1
fi

SUBDOMAIN=$1
PROJECT_DIR="projects/${SUBDOMAIN}"
NGINX_CONFIG="nginx-proxy/nginx/conf.d/${SUBDOMAIN}.conf"
FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"

# Verificar se projeto existe
if [ ! -f "$NGINX_CONFIG" ]; then
    echo -e "${RED}❌ Projeto não encontrado: ${SUBDOMAIN}${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  Você está prestes a remover:${NC}"
echo -e "   Projeto: ${RED}${SUBDOMAIN}${NC}"
echo -e "   Domínio: ${RED}${FULL_DOMAIN}${NC}"
echo -e "   Diretório: ${RED}${PROJECT_DIR}${NC}"
echo ""
echo -e "${RED}ATENÇÃO: Esta ação não pode ser desfeita!${NC}"
echo ""

read -p "Deseja realmente remover este projeto? (digite 'REMOVER' para confirmar): " CONFIRM

if [ "$CONFIRM" != "REMOVER" ]; then
    echo -e "${YELLOW}Operação cancelada.${NC}"
    exit 0
fi

# Parar containers do projeto
if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
    echo -e "${YELLOW}🛑 Parando containers...${NC}"
    cd "$PROJECT_DIR"
    docker-compose down 2>/dev/null || true
    cd - > /dev/null
    echo -e "${GREEN}✅ Containers parados${NC}"
fi

# Perguntar sobre volumes
if [ -d "$PROJECT_DIR" ]; then
    echo ""
    read -p "Deseja remover os volumes Docker também? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        echo -e "${YELLOW}🗑️  Removendo volumes...${NC}"
        cd "$PROJECT_DIR"
        docker-compose down -v 2>/dev/null || true
        cd - > /dev/null
        echo -e "${GREEN}✅ Volumes removidos${NC}"
    fi
fi

# Remover configuração do Nginx
echo -e "${YELLOW}🗑️  Removendo configuração do Nginx...${NC}"
rm -f "$NGINX_CONFIG"
echo -e "${GREEN}✅ Configuração do Nginx removida${NC}"

# Remover diretório do projeto
echo ""
read -p "Deseja remover o diretório do projeto? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    echo -e "${YELLOW}🗑️  Removendo diretório...${NC}"
    rm -rf "$PROJECT_DIR"
    echo -e "${GREEN}✅ Diretório removido${NC}"
else
    echo -e "${YELLOW}ℹ️  Diretório mantido: ${PROJECT_DIR}${NC}"
fi

# Perguntar sobre certificado SSL (se não for wildcard)
if [ "$USE_WILDCARD_SSL" != "true" ]; then
    echo ""
    read -p "Deseja remover o certificado SSL deste domínio? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        echo -e "${YELLOW}🗑️  Removendo certificado SSL...${NC}"
        docker exec certbot certbot delete --cert-name "${FULL_DOMAIN}" 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Certificado não encontrado ou já removido${NC}"
        }
        echo -e "${GREEN}✅ Certificado SSL removido${NC}"
    fi
fi

# Recarregar Nginx
echo -e "${YELLOW}🔄 Recarregando Nginx...${NC}"
docker exec nginx-proxy nginx -t && docker exec nginx-proxy nginx -s reload

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║    ✅ Projeto removido com sucesso!     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Listar projetos restantes
REMAINING=$(ls -1 nginx-proxy/nginx/conf.d/*.conf 2>/dev/null | grep -v "00-default.conf" | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo -e "${YELLOW}📋 Projetos restantes:${NC}"
    ls -1 nginx-proxy/nginx/conf.d/*.conf 2>/dev/null | sed 's/.*\///' | sed 's/\.conf$//' | grep -v "^00-default$" | while read proj; do
        echo -e "   • ${proj}"
    done
else
    echo -e "${YELLOW}ℹ️  Nenhum projeto restante${NC}"
fi
echo ""
