# Guia de Uso - Nginx VPS Setup

Guia completo de como usar o Nginx VPS Setup no dia a dia.

## 📑 Índice

- [Adicionar Novo Projeto](#adicionar-novo-projeto)
- [Obter Certificado SSL](#obter-certificado-ssl)
- [Fazer Deploy](#fazer-deploy)
- [Gerenciar Containers](#gerenciar-containers)
- [Monitoramento](#monitoramento)
- [Backup e Restore](#backup-e-restore)
- [Manutenção](#manutenção)

## 🆕 Adicionar Novo Projeto

### Método 1: Script Interativo (Recomendado)

```bash
cd /opt/vps
./scripts/add-project.sh
```

O script irá perguntar:
1. Nome do projeto
2. Domínio
3. Porta interna da aplicação
4. Tipo de projeto (single, load-balanced, with-database)

**Exemplo de uso:**
```
Nome do projeto: minha-api
Domínio: api.dominio.com
Porta: 3000
Tipo: 2 (Load Balanced)
```

O script irá:
- ✅ Criar diretório do projeto em `projects/minha-api`
- ✅ Copiar template apropriado
- ✅ Criar configuração Nginx em `nginx/conf.d/minha-api.conf`
- ✅ Testar e reload Nginx
- ✅ Opcionalmente obter certificado SSL

### Método 2: Manual

#### Passo 1: Copiar Template

```bash
cd /opt/vps

# Para aplicação simples
cp -r projects/templates/single-container projects/meu-app

# Para load balancing
cp -r projects/templates/load-balanced projects/minha-api

# Para aplicação com banco
cp -r projects/templates/with-database projects/meu-sistema
```

#### Passo 2: Configurar docker-compose.yml

```bash
cd projects/meu-app
nano docker-compose.yml
```

Edite:
- Nome dos serviços
- Imagem Docker
- Variáveis de ambiente
- Portas

#### Passo 3: Criar Configuração Nginx

```bash
cp nginx-config-example.conf ../../nginx/conf.d/meu-app.conf
nano ../../nginx/conf.d/meu-app.conf
```

Edite:
- `server_name` (seu domínio)
- `proxy_pass` (nome do container:porta)
- Certificados SSL paths

#### Passo 4: Testar e Reload Nginx

```bash
docker compose -f ../../docker-compose.yml exec nginx nginx -t
docker compose -f ../../docker-compose.yml exec nginx nginx -s reload
```

## 🔒 Obter Certificado SSL

### Usando o Script

```bash
cd /opt/vps
./scripts/get-ssl.sh meu-dominio.com
```

O script irá:
1. Verificar se DNS está apontando corretamente
2. Solicitar certificado ao Let's Encrypt
3. Instalar certificado
4. Reload Nginx
5. Mostrar informações do certificado

### Múltiplos Domínios

```bash
./scripts/get-ssl.sh app1.dominio.com
./scripts/get-ssl.sh app2.dominio.com
./scripts/get-ssl.sh api.dominio.com
```

### Wildcard Certificate (Avançado)

Para certificado wildcard (*.dominio.com), é necessário validação DNS:

```bash
docker compose run --rm certbot \
  certonly --manual \
  --preferred-challenges dns \
  --email seu-email@dominio.com \
  --agree-tos \
  -d "*.dominio.com" \
  -d "dominio.com"
```

Siga as instruções para adicionar registro TXT no DNS.

### Renovação Manual

```bash
# Renovar todos os certificados
docker compose run --rm certbot renew

# Renovar certificado específico
docker compose run --rm certbot renew --cert-name dominio.com

# Reload Nginx após renovação
docker compose exec nginx nginx -s reload
```

**Nota**: Renovação automática já está configurada via cron (2x por dia).

## 🚀 Fazer Deploy

### Método 1: Script de Deploy (Recomendado)

```bash
cd /opt/vps
./scripts/deploy.sh meu-app
```

Opções disponíveis:
1. **Build e deploy**: Reconstrói imagens e sobe containers
2. **Deploy apenas**: Sobe containers com imagens existentes
3. **Pull e deploy**: Baixa imagens do registry e sobe
4. **Restart**: Reinicia containers
5. **Stop**: Para containers

### Método 2: Manual

#### Deploy Simples

```bash
cd /opt/vps/projects/meu-app
docker compose up -d
```

#### Build e Deploy

```bash
cd /opt/vps/projects/meu-app
docker compose up -d --build
```

#### Pull e Deploy (usando registry)

```bash
cd /opt/vps/projects/meu-app
docker compose pull
docker compose up -d
```

#### Deploy com Zero Downtime (Load Balanced)

Para projetos load balanced, atualize um container por vez:

```bash
cd /opt/vps/projects/minha-api

# Rebuild imagem
docker compose build

# Atualizar container 1
docker compose up -d --no-deps --force-recreate minha-api-1
sleep 30

# Atualizar container 2
docker compose up -d --no-deps --force-recreate minha-api-2
sleep 30

# Atualizar container 3
docker compose up -d --no-deps --force-recreate minha-api-3
```

## 📊 Gerenciar Containers

### Ver Status

```bash
# Todos os containers
docker ps

# Containers de um projeto específico
cd /opt/vps/projects/meu-app
docker compose ps

# Containers do Nginx
cd /opt/vps
docker compose ps
```

### Logs

```bash
# Logs em tempo real
docker compose -f /opt/vps/projects/meu-app/docker-compose.yml logs -f

# Últimas 100 linhas
docker compose logs --tail=100

# Logs de um serviço específico
docker compose logs -f app

# Logs do Nginx
docker compose -f /opt/vps/docker-compose.yml logs -f nginx
```

### Restart

```bash
# Reiniciar projeto
cd /opt/vps/projects/meu-app
docker compose restart

# Reiniciar serviço específico
docker compose restart app

# Reiniciar Nginx
cd /opt/vps
docker compose restart nginx
```

### Stop/Start

```bash
# Parar projeto
cd /opt/vps/projects/meu-app
docker compose stop

# Iniciar projeto
docker compose start

# Parar e remover containers
docker compose down

# Parar e remover com volumes (CUIDADO: apaga dados!)
docker compose down -v
```

### Executar Comandos

```bash
# Shell no container
docker compose exec app sh

# Executar comando
docker compose exec app node --version

# Executar como usuário específico
docker compose exec -u node app npm list
```

## 📈 Monitoramento

### Verificar Recursos

```bash
# Uso de CPU, RAM e Rede em tempo real
docker stats

# Uso de disco
docker system df
docker system df -v

# Espaço dos volumes
docker volume ls
```

### Logs do Nginx

```bash
# Access log
docker compose exec nginx tail -f /var/log/nginx/access.log

# Error log
docker compose exec nginx tail -f /var/log/nginx/error.log

# Log de um projeto específico
docker compose exec nginx tail -f /var/log/nginx/meu-app-access.log
```

### Health Checks

```bash
# Ver containers unhealthy
docker ps --filter "health=unhealthy"

# Inspecionar health check
docker inspect --format='{{json .State.Health}}' meu-app | jq
```

### Testar Endpoints

```bash
# HTTP
curl -I http://dominio.com

# HTTPS
curl -I https://dominio.com

# Com timing
curl -w "@-" -o /dev/null -s https://dominio.com <<'EOF'
   time_namelookup:  %{time_namelookup}\n
      time_connect:  %{time_connect}\n
   time_appconnect:  %{time_appconnect}\n
     time_redirect:  %{time_redirect}\n
  time_pretransfer:  %{time_pretransfer}\n
time_starttransfer:  %{time_starttransfer}\n
                   ----------\n
        time_total:  %{time_total}\n
EOF
```

### Verificar Certificados SSL

```bash
# Ver certificados instalados
docker compose run --rm certbot certificates

# Ver expiração de certificado específico
echo | openssl s_client -connect dominio.com:443 -servername dominio.com 2>/dev/null | \
  openssl x509 -noout -dates

# Testar SSL
openssl s_client -connect dominio.com:443 -servername dominio.com
```

## 💾 Backup e Restore

### Fazer Backup

```bash
cd /opt/vps

# Backup automático (configurações + certificados)
./scripts/backup-configs.sh
```

Backups são salvos em `/opt/vps/backups/`.

### Backup Manual de Projeto

```bash
# Backup de um projeto específico
cd /opt/vps/projects/meu-app
tar -czf ~/meu-app-backup-$(date +%Y%m%d).tar.gz .
```

### Backup de Banco de Dados

#### PostgreSQL
```bash
docker compose exec meu-sistema-db \
  pg_dump -U usuario banco > backup-$(date +%Y%m%d).sql
```

#### MySQL
```bash
docker compose exec meu-sistema-db \
  mysqldump -u usuario -p banco > backup-$(date +%Y%m%d).sql
```

#### MongoDB
```bash
docker compose exec meu-sistema-db \
  mongodump --uri="mongodb://user:pass@localhost/banco" --out=/backup
```

### Restore

#### Restore de Configurações

```bash
cd /opt/vps
tar -xzf backups/nginx-vps-backup-20250119_120000.tar.gz -C /tmp/restore
cp /tmp/restore/nginx/conf.d/* nginx/conf.d/
docker compose exec nginx nginx -s reload
```

#### Restore de Certificados

```bash
docker run --rm \
  -v certbot-conf:/data \
  -v /opt/vps/backups:/backup \
  alpine \
  sh -c 'cd /data && tar -xzf /backup/certbot-conf-20250119_120000.tar.gz'

docker compose restart nginx
```

#### Restore de Banco de Dados

```bash
# PostgreSQL
cat backup.sql | docker compose exec -T meu-sistema-db \
  psql -U usuario banco

# MySQL
cat backup.sql | docker compose exec -T meu-sistema-db \
  mysql -u usuario -p banco

# MongoDB
docker compose exec meu-sistema-db \
  mongorestore --uri="mongodb://user:pass@localhost/banco" /backup/banco
```

## 🔧 Manutenção

### Atualizar Imagens Docker

```bash
cd /opt/vps

# Atualizar Nginx e Certbot
docker compose pull
docker compose up -d

# Atualizar projeto específico
cd projects/meu-app
docker compose pull
docker compose up -d
```

### Limpar Recursos

```bash
# Remover containers parados
docker container prune -f

# Remover imagens não usadas
docker image prune -a -f

# Remover volumes não usados (CUIDADO!)
docker volume prune -f

# Remover tudo não usado
docker system prune -a --volumes -f
```

### Reload Nginx (sem downtime)

```bash
# Testar configuração
docker compose exec nginx nginx -t

# Reload
docker compose exec nginx nginx -s reload
```

### Atualizar Sistema

```bash
# Atualizar pacotes
sudo apt-get update
sudo apt-get upgrade -y

# Atualizar Docker
sudo apt-get install --only-upgrade docker-ce docker-ce-cli containerd.io
```

### Rotacionar Logs Manualmente

```bash
# Forçar rotação
sudo logrotate -f /etc/logrotate.d/nginx-vps

# Reabrir arquivos de log no Nginx
docker compose exec nginx nginx -s reopen
```

## 🔐 Segurança

### Verificar Firewall

```bash
sudo ufw status verbose
```

### Verificar Fail2Ban

```bash
# Status geral
sudo fail2ban-client status

# Status do jail Nginx
sudo fail2ban-client status nginx-limit-req

# IPs banidos
sudo fail2ban-client get nginx-limit-req banned
```

### Desbanir IP

```bash
sudo fail2ban-client set nginx-limit-req unbanip 192.168.1.100
```

### Testar SSL

```bash
# SSL Labs (melhor ferramenta)
# Acesse: https://www.ssllabs.com/ssltest/analyze.html?d=seu-dominio.com

# Ou via comando
curl -sS https://ssl-tools.net/api/analyze?host=seu-dominio.com | jq
```

## 📚 Workflows Comuns

### Adicionar Nova Aplicação Completa

```bash
# 1. Adicionar projeto
./scripts/add-project.sh

# 2. Adicionar código
cd projects/meu-app
# ... copiar código, criar Dockerfile, etc.

# 3. Obter SSL
./scripts/get-ssl.sh meu-app.dominio.com

# 4. Deploy
./scripts/deploy.sh meu-app

# 5. Verificar
curl -I https://meu-app.dominio.com
```

### Atualizar Aplicação Existente

```bash
# 1. Pull código atualizado
cd /opt/vps/projects/meu-app
git pull origin main

# 2. Rebuild e deploy
./scripts/deploy.sh meu-app
# Escolher opção 1 (Build e deploy)

# 3. Verificar logs
docker compose logs -f
```

### Migrar Banco de Dados

```bash
# 1. Fazer backup
docker compose exec db pg_dump -U user db > backup.sql

# 2. Parar aplicação
docker compose stop app

# 3. Executar migração
docker compose exec app npm run migrate

# 4. Iniciar aplicação
docker compose start app

# 5. Verificar
docker compose logs -f app
```

## 🆘 Comandos de Emergência

### Nginx Não Responde

```bash
# Verificar se está rodando
docker compose ps nginx

# Reiniciar
docker compose restart nginx

# Ver logs
docker compose logs nginx

# Recriar container
docker compose up -d --force-recreate nginx
```

### Aplicação Não Responde

```bash
# Ver status
docker compose ps

# Ver logs
docker compose logs -f

# Restart
docker compose restart

# Recriar
docker compose up -d --force-recreate
```

### Disco Cheio

```bash
# Ver uso
df -h
docker system df

# Limpar
docker system prune -a --volumes -f

# Limpar logs antigos
sudo journalctl --vacuum-time=7d
```

### Certificado SSL Expirado

```bash
# Renovar forçadamente
docker compose run --rm certbot renew --force-renewal

# Reload Nginx
docker compose exec nginx nginx -s reload
```

---

Para mais detalhes, consulte:
- **Instalação**: [INSTALL.md](INSTALL.md)
- **Solução de Problemas**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **README**: [README.md](../README.md)
