#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Gerenciador de Certificados SSL     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Carregar variáveis do .env
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
    exit 1
fi

show_menu() {
    echo -e "${YELLOW}Escolha uma opção:${NC}"
    echo ""
    echo "  1) Listar certificados"
    echo "  2) Gerar certificado wildcard"
    echo "  3) Gerar certificado para subdomínio específico"
    echo "  4) Renovar certificados"
    echo "  5) Remover certificado"
    echo "  6) Verificar validade dos certificados"
    echo "  0) Sair"
    echo ""
    read -p "Opção: " option
}

list_certificates() {
    echo ""
    echo -e "${BLUE}📜 Certificados instalados:${NC}"
    echo ""
    docker exec certbot certbot certificates
}

generate_wildcard() {
    echo ""
    echo -e "${YELLOW}🔐 Gerando certificado wildcard para *.${DOMAIN}${NC}"
    echo -e "${YELLOW}⚠️  Você precisará adicionar um registro TXT no DNS${NC}"
    echo ""
    
    docker exec -it certbot certbot certonly \
        --manual \
        --preferred-challenges dns \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "*.$DOMAIN" \
        -d "$DOMAIN"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Certificado wildcard gerado com sucesso!${NC}"
        echo -e "${YELLOW}🔄 Recarregando Nginx...${NC}"
        docker exec nginx-proxy nginx -s reload
    else
        echo ""
        echo -e "${RED}❌ Erro ao gerar certificado wildcard${NC}"
    fi
}

generate_subdomain() {
    echo ""
    read -p "Digite o subdomínio (ex: api): " subdomain
    
    if [ -z "$subdomain" ]; then
        echo -e "${RED}❌ Subdomínio não pode ser vazio${NC}"
        return
    fi
    
    FULL_DOMAIN="${subdomain}.${DOMAIN}"
    
    echo -e "${YELLOW}🔐 Gerando certificado para ${FULL_DOMAIN}${NC}"
    
    docker exec certbot certbot certonly --webroot \
        --webroot-path /var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "${FULL_DOMAIN}"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Certificado gerado com sucesso!${NC}"
        echo -e "${YELLOW}🔄 Recarregando Nginx...${NC}"
        docker exec nginx-proxy nginx -s reload
    else
        echo ""
        echo -e "${RED}❌ Erro ao gerar certificado${NC}"
    fi
}

renew_certificates() {
    echo ""
    echo -e "${YELLOW}🔄 Renovando certificados...${NC}"
    
    docker exec certbot certbot renew
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Certificados renovados com sucesso!${NC}"
        echo -e "${YELLOW}🔄 Recarregando Nginx...${NC}"
        docker exec nginx-proxy nginx -s reload
    else
        echo ""
        echo -e "${RED}❌ Erro ao renovar certificados${NC}"
    fi
}

remove_certificate() {
    echo ""
    echo -e "${YELLOW}Certificados disponíveis:${NC}"
    docker exec certbot certbot certificates | grep "Certificate Name" | awk '{print "  - " $3}'
    echo ""
    
    read -p "Digite o nome do certificado para remover: " cert_name
    
    if [ -z "$cert_name" ]; then
        echo -e "${RED}❌ Nome do certificado não pode ser vazio${NC}"
        return
    fi
    
    echo ""
    echo -e "${RED}⚠️  ATENÇÃO: Você está prestes a remover o certificado: ${cert_name}${NC}"
    read -p "Confirma? (s/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        docker exec certbot certbot delete --cert-name "$cert_name"
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✅ Certificado removido com sucesso!${NC}"
        else
            echo ""
            echo -e "${RED}❌ Erro ao remover certificado${NC}"
        fi
    else
        echo -e "${YELLOW}Operação cancelada.${NC}"
    fi
}

check_validity() {
    echo ""
    echo -e "${BLUE}📅 Validade dos certificados:${NC}"
    echo ""
    
    docker exec certbot certbot certificates | grep -E "(Certificate Name|Expiry Date)" | while read line; do
        if echo "$line" | grep -q "Certificate Name"; then
            CERT_NAME=$(echo "$line" | awk '{print $3}')
            echo -e "${YELLOW}$CERT_NAME${NC}"
        elif echo "$line" | grep -q "Expiry Date"; then
            EXPIRY=$(echo "$line" | sed 's/.*Expiry Date: //')
            EXPIRY_DATE=$(date -d "$EXPIRY" +%s 2>/dev/null || echo "0")
            CURRENT_DATE=$(date +%s)
            DAYS_LEFT=$(( ($EXPIRY_DATE - $CURRENT_DATE) / 86400 ))
            
            if [ "$DAYS_LEFT" -lt 30 ]; then
                echo -e "  ${RED}Expira em: $EXPIRY ($DAYS_LEFT dias)${NC}"
            else
                echo -e "  ${GREEN}Expira em: $EXPIRY ($DAYS_LEFT dias)${NC}"
            fi
            echo ""
        fi
    done
}

# Menu principal
while true; do
    show_menu
    
    case $option in
        1)
            list_certificates
            ;;
        2)
            generate_wildcard
            ;;
        3)
            generate_subdomain
            ;;
        4)
            renew_certificates
            ;;
        5)
            remove_certificate
            ;;
        6)
            check_validity
            ;;
        0)
            echo -e "${GREEN}👋 Até logo!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opção inválida!${NC}"
            ;;
    esac
    
    echo ""
    read -p "Pressione ENTER para continuar..."
    clear
done
