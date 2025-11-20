#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Projetos Configurados            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Carregar variáveis do .env
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
    exit 1
fi

# Verificar se há projetos
if [ ! -d "nginx-proxy/nginx/conf.d" ]; then
    echo -e "${YELLOW}ℹ️  Nenhum projeto encontrado${NC}"
    exit 0
fi

PROJECTS=$(ls -1 nginx-proxy/nginx/conf.d/*.conf 2>/dev/null | sed 's/.*\///' | sed 's/\.conf$//' | grep -v "^00-default$" || true)

if [ -z "$PROJECTS" ]; then
    echo -e "${YELLOW}ℹ️  Nenhum projeto encontrado${NC}"
    echo ""
    echo -e "${YELLOW}💡 Para adicionar um projeto, execute:${NC}"
    echo -e "   ${GREEN}./scripts/add-project.sh${NC}"
    exit 0
fi

# Contadores
TOTAL=0
RUNNING=0
STOPPED=0

echo -e "${BLUE}Domain: ${DOMAIN}${NC}"
echo -e "${BLUE}SSL Mode: $([ "$USE_WILDCARD_SSL" = "true" ] && echo "Wildcard" || echo "Individual")${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-20s %-35s %-15s %s\n" "SUBDOMÍNIO" "URL" "STATUS" "CONTAINERS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while IFS= read -r project; do
    TOTAL=$((TOTAL + 1))
    FULL_DOMAIN="${project}.${DOMAIN}"
    PROJECT_DIR="projects/${project}"
    
    # Verificar status dos containers
    if [ -d "$PROJECT_DIR" ]; then
        # Contar containers rodando
        CONTAINER_COUNT=$(docker ps --filter "name=${project}" --format "{{.Names}}" 2>/dev/null | wc -l)
        CONTAINER_TOTAL=$(docker ps -a --filter "name=${project}" --format "{{.Names}}" 2>/dev/null | wc -l)
        
        if [ "$CONTAINER_COUNT" -gt 0 ]; then
            STATUS="${GREEN}●${NC} Running"
            RUNNING=$((RUNNING + 1))
            CONTAINERS="${GREEN}${CONTAINER_COUNT}/${CONTAINER_TOTAL}${NC}"
        else
            if [ "$CONTAINER_TOTAL" -gt 0 ]; then
                STATUS="${RED}●${NC} Stopped"
                STOPPED=$((STOPPED + 1))
                CONTAINERS="${RED}0/${CONTAINER_TOTAL}${NC}"
            else
                STATUS="${YELLOW}●${NC} No containers"
                CONTAINERS="${YELLOW}-${NC}"
            fi
        fi
    else
        STATUS="${YELLOW}●${NC} No directory"
        CONTAINERS="${YELLOW}-${NC}"
    fi
    
    printf "%-20s %-35s %-24s %b\n" "$project" "https://$FULL_DOMAIN" "$STATUS" "$CONTAINERS"
done <<< "$PROJECTS"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Estatísticas
echo -e "${BLUE}📊 Resumo:${NC}"
echo -e "   Total de projetos: ${YELLOW}${TOTAL}${NC}"
echo -e "   Rodando: ${GREEN}${RUNNING}${NC}"
echo -e "   Parados: ${RED}${STOPPED}${NC}"
echo ""

# Informações do Nginx
NGINX_STATUS=$(docker ps --filter "name=nginx-proxy" --format "{{.Status}}" 2>/dev/null || echo "Not running")
if echo "$NGINX_STATUS" | grep -q "Up"; then
    echo -e "${GREEN}✅ Nginx Proxy: ${NGINX_STATUS}${NC}"
else
    echo -e "${RED}❌ Nginx Proxy: ${NGINX_STATUS}${NC}"
fi

# Informações de certificados SSL
echo ""
echo -e "${BLUE}🔐 Certificados SSL:${NC}"
if [ "$USE_WILDCARD_SSL" = "true" ]; then
    if docker exec certbot certbot certificates 2>/dev/null | grep -q "*.$DOMAIN"; then
        EXPIRY=$(docker exec certbot certbot certificates 2>/dev/null | grep -A 5 "*.$DOMAIN" | grep "Expiry Date" | awk '{print $3, $4}')
        echo -e "   ${GREEN}✓${NC} Wildcard certificate: *.$DOMAIN"
        echo -e "     Expira em: ${YELLOW}${EXPIRY}${NC}"
    else
        echo -e "   ${YELLOW}⚠${NC}  Certificado wildcard não encontrado"
    fi
else
    CERT_COUNT=$(docker exec certbot certbot certificates 2>/dev/null | grep "Certificate Name" | wc -l)
    echo -e "   ${GREEN}${CERT_COUNT}${NC} certificado(s) individual(is)"
fi

echo ""
echo -e "${YELLOW}💡 Comandos úteis:${NC}"
echo -e "   Ver detalhes de um projeto: ${GREEN}cd projects/<nome> && docker-compose ps${NC}"
echo -e "   Ver logs do Nginx: ${GREEN}docker logs nginx-proxy -f${NC}"
echo -e "   Adicionar projeto: ${GREEN}./scripts/add-project.sh${NC}"
echo -e "   Remover projeto: ${GREEN}./scripts/remove-project.sh <nome>${NC}"
echo ""
