#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Backup Manager                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Carregar variáveis do .env
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
    exit 1
fi

# Diretório de backup
BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="vps-nginx-backup-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Criar diretório de backup
mkdir -p "$BACKUP_PATH"

echo -e "${YELLOW}📦 Iniciando backup...${NC}"
echo -e "   Local: ${BLUE}${BACKUP_PATH}${NC}"
echo ""

# Backup de certificados SSL
echo -e "${YELLOW}🔐 Fazendo backup dos certificados SSL...${NC}"
if [ -d "nginx-proxy/certbot/conf" ]; then
    mkdir -p "${BACKUP_PATH}/ssl"
    cp -r nginx-proxy/certbot/conf/* "${BACKUP_PATH}/ssl/" 2>/dev/null || true
    echo -e "${GREEN}✅ Certificados SSL salvos${NC}"
else
    echo -e "${YELLOW}⚠️  Nenhum certificado encontrado${NC}"
fi

# Backup de configurações do Nginx
echo -e "${YELLOW}📝 Fazendo backup das configurações do Nginx...${NC}"
if [ -d "nginx-proxy/nginx/conf.d" ]; then
    mkdir -p "${BACKUP_PATH}/nginx-configs"
    cp -r nginx-proxy/nginx/conf.d/* "${BACKUP_PATH}/nginx-configs/" 2>/dev/null || true
    echo -e "${GREEN}✅ Configurações do Nginx salvas${NC}"
else
    echo -e "${YELLOW}⚠️  Nenhuma configuração encontrada${NC}"
fi

# Backup do docker-compose do nginx-proxy
echo -e "${YELLOW}🐳 Fazendo backup do docker-compose...${NC}"
if [ -f "nginx-proxy/docker-compose.yml" ]; then
    cp nginx-proxy/docker-compose.yml "${BACKUP_PATH}/"
    echo -e "${GREEN}✅ Docker-compose salvo${NC}"
fi

# Backup do .env
echo -e "${YELLOW}⚙️  Fazendo backup das variáveis de ambiente...${NC}"
if [ -f ".env" ]; then
    cp .env "${BACKUP_PATH}/"
    echo -e "${GREEN}✅ Arquivo .env salvo${NC}"
fi

# Listar projetos e seus docker-compose
echo -e "${YELLOW}📂 Fazendo backup dos projetos...${NC}"
if [ -d "projects" ]; then
    mkdir -p "${BACKUP_PATH}/projects"
    
    # Copiar apenas os docker-compose.yml e .env de cada projeto
    for project_dir in projects/*/; do
        if [ -d "$project_dir" ]; then
            project_name=$(basename "$project_dir")
            mkdir -p "${BACKUP_PATH}/projects/${project_name}"
            
            # Copiar docker-compose
            if [ -f "${project_dir}docker-compose.yml" ]; then
                cp "${project_dir}docker-compose.yml" "${BACKUP_PATH}/projects/${project_name}/"
            fi
            
            # Copiar .env se existir
            if [ -f "${project_dir}.env" ]; then
                cp "${project_dir}.env" "${BACKUP_PATH}/projects/${project_name}/"
            fi
            
            # Copiar README se existir
            if [ -f "${project_dir}README.md" ]; then
                cp "${project_dir}README.md" "${BACKUP_PATH}/projects/${project_name}/"
            fi
            
            echo -e "   ${GREEN}✓${NC} ${project_name}"
        fi
    done
    
    echo -e "${GREEN}✅ Projetos salvos${NC}"
else
    echo -e "${YELLOW}⚠️  Nenhum projeto encontrado${NC}"
fi

# Criar arquivo de informações do backup
cat > "${BACKUP_PATH}/backup-info.txt" <<EOF
VPS Nginx Manager - Backup
==========================

Data: $(date)
Domínio: ${DOMAIN}
Modo SSL: $([ "$USE_WILDCARD_SSL" = "true" ] && echo "Wildcard" || echo "Individual")

Conteúdo do backup:
- Certificados SSL
- Configurações do Nginx
- Docker-compose dos projetos
- Variáveis de ambiente (.env)

Para restaurar:
1. Copie os certificados para nginx-proxy/certbot/conf/
2. Copie as configurações para nginx-proxy/nginx/conf.d/
3. Restaure o docker-compose.yml
4. Restaure o .env
5. Execute: ./scripts/reload-nginx.sh
EOF

# Comprimir backup
echo ""
echo -e "${YELLOW}📦 Comprimindo backup...${NC}"
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
COMPRESSED_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)

# Remover diretório não comprimido
rm -rf "$BACKUP_NAME"
cd ..

echo -e "${GREEN}✅ Backup comprimido: ${COMPRESSED_SIZE}${NC}"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      ✅ Backup concluído!               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📁 Arquivo: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz${NC}"
echo -e "${BLUE}📏 Tamanho: ${COMPRESSED_SIZE}${NC}"
echo ""

# Perguntar se quer limpar backups antigos
BACKUP_COUNT=$(ls -1 ${BACKUP_DIR}/*.tar.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 5 ]; then
    echo -e "${YELLOW}⚠️  Você tem ${BACKUP_COUNT} backups${NC}"
    read -p "Deseja manter apenas os 5 mais recentes? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        cd "$BACKUP_DIR"
        ls -t *.tar.gz | tail -n +6 | xargs rm -f
        echo -e "${GREEN}✅ Backups antigos removidos${NC}"
        cd ..
    fi
fi

# Mostrar backups existentes
echo ""
echo -e "${BLUE}📋 Backups disponíveis:${NC}"
ls -lht ${BACKUP_DIR}/*.tar.gz 2>/dev/null | head -5 | awk '{print "   " $9 " (" $5 ")"}'
echo ""

echo -e "${YELLOW}💡 Dicas:${NC}"
echo -e "   • Baixe o backup para sua máquina local"
echo -e "   • Guarde em local seguro (Google Drive, Dropbox, etc)"
echo -e "   • Para restaurar: tar -xzf ${BACKUP_NAME}.tar.gz"
echo ""
