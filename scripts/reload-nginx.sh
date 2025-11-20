#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 Recarregando Nginx...${NC}"

# Verificar se Nginx está rodando
if ! docker ps | grep -q nginx-proxy; then
    echo -e "${RED}❌ Nginx Proxy não está rodando!${NC}"
    echo -e "${YELLOW}Iniciando Nginx Proxy...${NC}"
    cd nginx-proxy
    docker-compose up -d
    cd ..
    exit 0
fi

# Testar configuração
echo -e "${YELLOW}🔍 Testando configuração...${NC}"
if docker exec nginx-proxy nginx -t 2>&1 | grep -q "syntax is ok"; then
    echo -e "${GREEN}✅ Configuração válida${NC}"
    
    # Recarregar
    docker exec nginx-proxy nginx -s reload
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Nginx recarregado com sucesso!${NC}"
    else
        echo -e "${RED}❌ Erro ao recarregar Nginx${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Erro na configuração do Nginx!${NC}"
    echo ""
    echo -e "${YELLOW}Detalhes do erro:${NC}"
    docker exec nginx-proxy nginx -t
    exit 1
fi
