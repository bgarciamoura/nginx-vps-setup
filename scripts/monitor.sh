#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Sistema de Monitoramento          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Carregar variáveis do .env
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
    exit 1
fi

# Função para verificar status de um serviço
check_service() {
    local service_name=$1
    local container_name=$2
    
    if docker ps | grep -q "$container_name"; then
        echo -e "${GREEN}✓${NC} $service_name está rodando"
        return 0
    else
        echo -e "${RED}✗${NC} $service_name NÃO está rodando"
        return 1
    fi
}

# Função para verificar certificado SSL
check_ssl_cert() {
    local domain=$1
    local days_left=0
    
    # Verificar certificado wildcard
    if [ "$USE_WILDCARD_SSL" = "true" ]; then
        CERT_INFO=$(docker exec certbot certbot certificates 2>/dev/null | grep -A 10 "*.$DOMAIN")
    else
        CERT_INFO=$(docker exec certbot certbot certificates 2>/dev/null | grep -A 10 "$domain")
    fi
    
    if [ -n "$CERT_INFO" ]; then
        EXPIRY=$(echo "$CERT_INFO" | grep "Expiry Date" | sed 's/.*Expiry Date: //')
        EXPIRY_DATE=$(date -d "$EXPIRY" +%s 2>/dev/null)
        CURRENT_DATE=$(date +%s)
        days_left=$(( ($EXPIRY_DATE - $CURRENT_DATE) / 86400 ))
        
        if [ "$days_left" -lt 30 ]; then
            echo -e "${RED}⚠${NC}  Certificado expira em ${days_left} dias"
        else
            echo -e "${GREEN}✓${NC} Certificado válido (${days_left} dias restantes)"
        fi
    else
        echo -e "${YELLOW}⚠${NC}  Certificado não encontrado"
    fi
}

# Verificar status do sistema
echo -e "${BLUE}🖥️  Status do Sistema${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# CPU e Memória
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
MEM_USAGE=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}')

echo -e "   CPU: ${YELLOW}${CPU_USAGE}%${NC}"
echo -e "   Memória: ${YELLOW}${MEM_USAGE}${NC}"
echo -e "   Disco: ${YELLOW}${DISK_USAGE}${NC}"
echo ""

# Verificar serviços principais
echo -e "${BLUE}🐳 Status dos Serviços${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NGINX_OK=0
CERTBOT_OK=0

check_service "Nginx Proxy" "nginx-proxy" && NGINX_OK=1
check_service "Certbot" "certbot" && CERTBOT_OK=1
echo ""

# Verificar projetos
echo -e "${BLUE}📦 Status dos Projetos${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PROJECTS=$(ls -1 nginx-proxy/nginx/conf.d/*.conf 2>/dev/null | sed 's/.*\///' | sed 's/\.conf$//' | grep -v "^00-default$" || true)
PROJECT_ISSUES=0

if [ -z "$PROJECTS" ]; then
    echo -e "${YELLOW}   Nenhum projeto configurado${NC}"
else
    while IFS= read -r project; do
        FULL_DOMAIN="${project}.${DOMAIN}"
        PROJECT_DIR="projects/${project}"
        
        # Contar containers rodando
        RUNNING=$(docker ps --filter "name=${project}" --format "{{.Names}}" 2>/dev/null | wc -l)
        TOTAL=$(docker ps -a --filter "name=${project}" --format "{{.Names}}" 2>/dev/null | wc -l)
        
        if [ "$RUNNING" -gt 0 ] && [ "$RUNNING" -eq "$TOTAL" ]; then
            echo -e "${GREEN}✓${NC} ${project} (${RUNNING}/${TOTAL} containers)"
        elif [ "$RUNNING" -gt 0 ]; then
            echo -e "${YELLOW}⚠${NC} ${project} (${RUNNING}/${TOTAL} containers - alguns parados)"
            PROJECT_ISSUES=$((PROJECT_ISSUES + 1))
        else
            echo -e "${RED}✗${NC} ${project} (${RUNNING}/${TOTAL} containers - todos parados)"
            PROJECT_ISSUES=$((PROJECT_ISSUES + 1))
        fi
    done <<< "$PROJECTS"
fi
echo ""

# Verificar certificados SSL
echo -e "${BLUE}🔐 Status dos Certificados SSL${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$USE_WILDCARD_SSL" = "true" ]; then
    echo -e "   Modo: ${YELLOW}Wildcard${NC}"
    check_ssl_cert "*.$DOMAIN"
else
    echo -e "   Modo: ${YELLOW}Individual${NC}"
    if [ -n "$PROJECTS" ]; then
        while IFS= read -r project; do
            FULL_DOMAIN="${project}.${DOMAIN}"
            echo -n "   $project: "
            check_ssl_cert "$FULL_DOMAIN"
        done <<< "$PROJECTS"
    fi
fi
echo ""

# Verificar uso de recursos dos containers
echo -e "${BLUE}📊 Uso de Recursos (Top 5)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -6
echo ""

# Verificar logs recentes de erros
echo -e "${BLUE}⚠️  Erros Recentes (últimas 24h)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NGINX_ERRORS=$(docker logs nginx-proxy --since 24h 2>&1 | grep -i error | wc -l)
if [ "$NGINX_ERRORS" -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC}  Nginx: ${NGINX_ERRORS} erros encontrados"
    echo -e "   ${BLUE}Ver logs:${NC} docker logs nginx-proxy | grep -i error"
else
    echo -e "${GREEN}✓${NC} Nginx: Nenhum erro"
fi
echo ""

# Resumo geral
echo -e "${BLUE}📋 Resumo${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ISSUES=0
[ "$NGINX_OK" -eq 0 ] && ISSUES=$((ISSUES + 1))
[ "$CERTBOT_OK" -eq 0 ] && ISSUES=$((ISSUES + 1))
ISSUES=$((ISSUES + PROJECT_ISSUES))

if [ "$ISSUES" -eq 0 ]; then
    echo -e "${GREEN}✅ Sistema operacional - Nenhum problema detectado${NC}"
else
    echo -e "${YELLOW}⚠️  ${ISSUES} problema(s) detectado(s)${NC}"
    echo ""
    echo -e "${YELLOW}Recomendações:${NC}"
    
    if [ "$NGINX_OK" -eq 0 ]; then
        echo -e "   • Iniciar Nginx Proxy: ${GREEN}cd nginx-proxy && docker-compose up -d${NC}"
    fi
    
    if [ "$CERTBOT_OK" -eq 0 ]; then
        echo -e "   • Iniciar Certbot: ${GREEN}cd nginx-proxy && docker-compose up -d${NC}"
    fi
    
    if [ "$PROJECT_ISSUES" -gt 0 ]; then
        echo -e "   • Verificar projetos parados: ${GREEN}./scripts/list-projects.sh${NC}"
        echo -e "   • Iniciar projeto: ${GREEN}cd projects/<nome> && docker-compose up -d${NC}"
    fi
fi

echo ""

# Verificar espaço em disco
DISK_PERCENT=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
if [ "$DISK_PERCENT" -gt 80 ]; then
    echo -e "${RED}⚠️  ALERTA: Disco com ${DISK_PERCENT}% de uso!${NC}"
    echo -e "${YELLOW}   Considere limpar: docker system prune -a${NC}"
    echo ""
fi

# Mostrar tempo de atividade
UPTIME=$(uptime -p)
echo -e "${BLUE}⏰ Tempo de atividade: ${UPTIME}${NC}"
echo ""

# Opção de monitoramento contínuo
if [ "$1" = "--watch" ] || [ "$1" = "-w" ]; then
    echo -e "${YELLOW}Modo de monitoramento contínuo ativado${NC}"
    echo -e "${YELLOW}Atualizando a cada 5 segundos... (Ctrl+C para sair)${NC}"
    echo ""
    
    while true; do
        sleep 5
        clear
        $0  # Chama o script novamente
    done
fi
