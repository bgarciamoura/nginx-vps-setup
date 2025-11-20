# 🚀 Guia de Início Rápido

Este guia vai te ajudar a configurar tudo em menos de 10 minutos.

## Passo 1: Preparar a VPS

```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Docker (se ainda não tiver)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## Passo 2: Clonar e Configurar

```bash
# Clonar o repositório
git clone <seu-repositorio>
cd vps-nginx-manager

# Configurar variáveis
cp .env.example .env
nano .env
```

Edite o `.env`:
```env
DOMAIN=seudominio.com
EMAIL=seu@email.com
USE_WILDCARD_SSL=true
```

## Passo 3: Executar Setup

```bash
# Dar permissão aos scripts
chmod +x scripts/*.sh

# Executar setup
./scripts/setup.sh
```

## Passo 4: Adicionar Primeiro Projeto

```bash
# Modo interativo
./scripts/add-project.sh

# Ou diretamente
./scripts/add-project.sh api api-backend 4000 3
```

## Passo 5: Deploy do Projeto

```bash
# Ir para o diretório do projeto
cd projects/api

# Editar docker-compose.yml
nano docker-compose.yml

# Adicionar sua imagem/código
# Depois subir
docker-compose up -d
```

## Passo 6: Verificar

```bash
# Listar projetos
./scripts/list-projects.sh

# Ver logs
docker logs nginx-proxy -f
```

## 🎉 Pronto!

Acesse: `https://api.seudominio.com`

## 📚 Comandos Úteis

```bash
# Adicionar novo projeto
./scripts/add-project.sh

# Listar projetos
./scripts/list-projects.sh

# Remover projeto
./scripts/remove-project.sh api

# Gerenciar SSL
./scripts/ssl-manager.sh

# Recarregar Nginx
./scripts/reload-nginx.sh

# Ver logs
docker logs nginx-proxy -f
docker logs certbot -f
```

## 🔧 Troubleshooting

### Projeto não acessível?

1. Verifique DNS: `nslookup api.seudominio.com`
2. Verifique container: `docker ps | grep api`
3. Verifique logs: `docker logs nginx-proxy`

### Erro de SSL?

```bash
# Listar certificados
docker exec certbot certbot certificates

# Renovar manualmente
docker exec certbot certbot renew
docker exec nginx-proxy nginx -s reload
```

### Container não inicia?

```bash
cd projects/api
docker-compose logs
```

## 💡 Dicas

1. **Sempre use a rede proxy-network** nos seus projetos
2. **Configure health checks** nos seus containers
3. **Use volumes** para persistir dados importantes
4. **Faça backup** dos certificados SSL regularmente
5. **Monitore os logs** periodicamente

Para mais detalhes, consulte o [README.md](README.md) completo.
