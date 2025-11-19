# Guia de Solução de Problemas - Nginx VPS Setup

Soluções para problemas comuns encontrados ao usar o Nginx VPS Setup.

## 📑 Índice

- [Problemas de Instalação](#problemas-de-instalação)
- [Problemas com Docker](#problemas-com-docker)
- [Problemas com Nginx](#problemas-com-nginx)
- [Problemas com SSL/Certbot](#problemas-com-sslcertbot)
- [Problemas de Rede](#problemas-de-rede)
- [Problemas com Aplicações](#problemas-com-aplicações)
- [Problemas de Performance](#problemas-de-performance)

---

## 🔧 Problemas de Instalação

### Script setup.sh falha

**Sintoma**: Script para com erro durante execução

**Soluções**:

```bash
# 1. Verificar se está rodando como root
sudo ./scripts/setup.sh

# 2. Verificar logs de erro
cat /var/log/syslog | grep -i error

# 3. Verificar conexão com internet
ping -c 4 google.com

# 4. Verificar espaço em disco
df -h

# 5. Atualizar repositórios manualmente
sudo apt-get update
sudo apt-get upgrade -y
```

### Erro ao instalar Docker

**Sintoma**: `apt-get install docker-ce` falha

**Soluções**:

```bash
# 1. Remover versões antigas
sudo apt-get remove docker docker-engine docker.io containerd runc

# 2. Limpar cache do apt
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get update

# 3. Instalar via script oficial Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 4. Verificar
docker --version
```

### UFW bloqueia SSH após habilitar

**Sintoma**: Perde conexão SSH após rodar setup.sh

**Prevenção**:
```bash
# SEMPRE permitir SSH ANTES de habilitar UFW
sudo ufw allow 22/tcp
sudo ufw enable
```

**Solução**:
- Acesse via console web do provedor (Hostinger, DigitalOcean, etc.)
- Execute: `sudo ufw allow 22/tcp && sudo ufw reload`

---

## 🐳 Problemas com Docker

### Containers não iniciam

**Sintoma**: `docker compose ps` mostra containers como "Exited"

**Diagnóstico**:
```bash
# Ver logs detalhados
docker compose logs

# Ver motivo da saída
docker inspect <container-id> | jq '.[0].State'

# Ver últimos eventos
docker events --since 10m
```

**Soluções comuns**:

1. **Porta já em uso**:
```bash
# Verificar quem está usando porta 80/443
sudo netstat -tulpn | grep -E '(80|443)'

# Parar processo conflitante
sudo kill <PID>
```

2. **Erro de configuração**:
```bash
# Testar configuração Nginx
docker compose exec nginx nginx -t

# Se não conseguir exec, montar volume e testar manualmente
docker run --rm -v $(pwd)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx:alpine nginx -t
```

3. **Falta de recursos**:
```bash
# Verificar memória
free -h

# Verificar disco
df -h

# Criar swap se necessário (veja INSTALL.md)
```

### Erro "network not found"

**Sintoma**: `ERROR: Network proxy-network declared as external, but could not be found`

**Solução**:
```bash
# Criar rede
docker network create proxy-network

# Verificar
docker network ls | grep proxy-network
```

### Erro "volume not found"

**Sintoma**: Erro relacionado a volumes

**Solução**:
```bash
# Criar volumes manualmente
docker volume create certbot-conf
docker volume create certbot-www
docker volume create nginx-logs

# Ou deixar o compose criar
docker compose up -d
```

### Docker ocupa muito espaço

**Sintoma**: Disco está cheio devido ao Docker

**Solução**:
```bash
# Ver uso
docker system df

# Limpar imagens não usadas
docker image prune -a -f

# Limpar containers parados
docker container prune -f

# Limpar volumes não usados (CUIDADO!)
docker volume prune -f

# Limpar tudo
docker system prune -a --volumes -f

# Limpar logs
sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log
```

---

## 🌐 Problemas com Nginx

### Nginx não inicia

**Sintoma**: Container nginx fica em "Restarting" ou "Exited"

**Diagnóstico**:
```bash
# Ver logs
docker compose logs nginx

# Testar configuração
docker compose exec nginx nginx -t
# Se container não está rodando:
docker run --rm -v $(pwd)/nginx:/etc/nginx:ro nginx:alpine nginx -t
```

**Erros comuns**:

1. **Erro de sintaxe no .conf**:
```
nginx: [emerg] unexpected "}" in nginx.conf:42
```
**Solução**: Revisar arquivo, verificar ponto e vírgula, chaves, etc.

2. **Porta já em uso**:
```
nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)
```
**Solução**:
```bash
sudo netstat -tulpn | grep :80
sudo kill <PID>
```

3. **Arquivo de certificado não encontrado**:
```
nginx: [emerg] cannot load certificate "/etc/letsencrypt/live/...
```
**Solução**: Obter certificado ou comentar bloco HTTPS temporariamente

### Erro 502 Bad Gateway

**Sintoma**: Site retorna "502 Bad Gateway"

**Causas e Soluções**:

1. **Container da aplicação não está rodando**:
```bash
# Verificar status
docker compose ps

# Ver logs
docker compose logs app

# Reiniciar
docker compose restart app
```

2. **Nome do container está errado no proxy_pass**:
```bash
# Verificar nome no docker-compose.yml
docker compose ps

# Deve coincidir com proxy_pass no nginx .conf
# Exemplo: proxy_pass http://meu-app:3000;
```

3. **Aplicação não está na mesma rede**:
```bash
# Verificar rede do container
docker inspect <container> | jq '.[0].NetworkSettings.Networks'

# Deve estar em "proxy-network"
# Adicionar ao docker-compose.yml:
# networks:
#   - proxy-network
```

4. **Porta está errada**:
```bash
# Verificar porta que a aplicação escuta
docker compose logs app | grep -i "listening\|started"

# Deve coincidir com proxy_pass
# Exemplo: proxy_pass http://meu-app:3000;
#          app deve escutar na porta 3000
```

5. **Aplicação demora para iniciar**:
```bash
# Adicionar proxy_read_timeout maior
# No nginx .conf:
proxy_read_timeout 300s;
```

### Erro 504 Gateway Timeout

**Sintoma**: Site retorna "504 Gateway Timeout"

**Soluções**:

```nginx
# Aumentar timeouts no nginx .conf
proxy_connect_timeout 600s;
proxy_send_timeout 600s;
proxy_read_timeout 600s;
```

```bash
# Reload Nginx
docker compose exec nginx nginx -s reload
```

### Erro 413 Request Entity Too Large

**Sintoma**: Erro ao fazer upload de arquivos grandes

**Solução**:

```nginx
# No nginx .conf ou .conf do projeto
client_max_body_size 100M;  # Ajuste conforme necessário
```

```bash
# Reload Nginx
docker compose exec nginx nginx -s reload
```

### Erro 429 Too Many Requests

**Sintoma**: Site retorna "429 Too Many Requests"

**Causa**: Rate limiting ativado

**Soluções**:

1. **Temporariamente desabilitar rate limit** (debug):
```nginx
# Comentar no .conf
# limit_req zone=general burst=20 nodelay;
```

2. **Aumentar limite**:
```nginx
# No nginx.conf
limit_req_zone $binary_remote_addr zone=general:10m rate=100r/s;  # Aumentar de 10r/s

# No .conf do site
limit_req zone=general burst=100 nodelay;  # Aumentar burst
```

3. **Desbanir IP (se usando Fail2Ban)**:
```bash
sudo fail2ban-client set nginx-limit-req unbanip <IP>
```

---

## 🔒 Problemas com SSL/Certbot

### Certbot falha ao obter certificado

**Sintoma**: `./scripts/get-ssl.sh` falha

**Diagnóstico**:
```bash
# Ver logs do Certbot
docker compose logs certbot

# Testar manualmente com debug
docker compose run --rm certbot \
  certonly --webroot \
  --webroot-path=/var/www/certbot \
  --email seu@email.com \
  --agree-tos \
  --dry-run \  # Teste sem obter certificado real
  -d seu-dominio.com
```

**Erros comuns**:

1. **DNS não está apontando corretamente**:
```
Domain: seu-dominio.com
Type:   unauthorized
Detail: Invalid response from http://seu-dominio.com/.well-known/acme-challenge/...
```

**Solução**:
```bash
# Verificar DNS
dig +short seu-dominio.com

# Deve retornar o IP da VPS
curl ifconfig.me

# Aguardar propagação DNS (até 48h)
```

2. **Porta 80 não acessível**:
```
Detail: Fetching http://seu-dominio.com/.well-known/acme-challenge/...: Connection refused
```

**Solução**:
```bash
# Verificar firewall
sudo ufw status

# Permitir porta 80
sudo ufw allow 80/tcp

# Verificar se Nginx está ouvindo na porta 80
docker compose ps
curl http://localhost/.well-known/acme-challenge/test
```

3. **Limite de requisições**:
```
too many certificates already issued for: dominio.com
```

**Solução**: Aguardar 1 semana. Let's Encrypt limita 5 certificados/semana por domínio.

**Workaround**: Usar `--staging` para testes:
```bash
docker compose run --rm certbot \
  certonly --webroot \
  --staging \  # Usar ambiente de staging
  -d seu-dominio.com
```

### Certificado SSL expirado

**Sintoma**: Navegador mostra "SEC_ERROR_EXPIRED_CERTIFICATE"

**Solução**:
```bash
# Verificar data de expiração
docker compose run --rm certbot certificates

# Renovar
docker compose run --rm certbot renew --force-renewal

# Reload Nginx
docker compose exec nginx nginx -s reload
```

**Verificar renovação automática**:
```bash
# Ver crontab
crontab -l

# Deve ter linha similar a:
# 30 2,14 * * * cd /opt/vps && docker compose run --rm certbot renew ...

# Testar renovação
docker compose run --rm certbot renew --dry-run
```

### Erro "SSL_ERROR_RX_RECORD_TOO_LONG"

**Sintoma**: Navegador mostra erro SSL estranho

**Causa**: Nginx está servindo HTTP na porta 443 (geralmente após configuração incorreta)

**Solução**:
```bash
# Verificar configuração
docker compose exec nginx nginx -t

# Revisar blocos server listen 443
# Deve ter "ssl" após "443":
# listen 443 ssl http2;  # Correto
# listen 443;             # Errado
```

---

## 🌍 Problemas de Rede

### Containers não conseguem se comunicar

**Sintoma**: Nginx não consegue fazer proxy para aplicação (502 Bad Gateway)

**Diagnóstico**:
```bash
# Ver redes dos containers
docker inspect nginx-proxy | jq '.[0].NetworkSettings.Networks'
docker inspect meu-app | jq '.[0].NetworkSettings.Networks'

# Devem estar na mesma rede (proxy-network)
```

**Solução**:
```bash
# Adicionar container à rede
docker network connect proxy-network meu-app

# Ou adicionar no docker-compose.yml:
networks:
  - proxy-network

networks:
  proxy-network:
    external: true
```

**Testar conectividade**:
```bash
# Do Nginx para app
docker compose exec nginx ping meu-app

# Do app para Nginx
docker compose exec meu-app ping nginx-proxy

# Resolver DNS
docker compose exec nginx nslookup meu-app
```

### DNS interno não resolve

**Sintoma**: `ping meu-app` retorna "unknown host"

**Solução**:
```bash
# Verificar que o nome usado é o nome do SERVICE no docker-compose.yml
# NÃO o container_name

# Correto:
services:
  app:  # <- Use este nome
    container_name: meu-app-1

# No Nginx: proxy_pass http://app:3000;

# Reiniciar Docker daemon (última opção)
sudo systemctl restart docker
```

### Portas não acessíveis externamente

**Sintoma**: `curl http://IP-DA-VPS` falha, mas `curl http://localhost` funciona

**Diagnóstico**:
```bash
# Ver portas abertas
sudo netstat -tulpn | grep -E '(80|443)'

# Ver firewall
sudo ufw status

# Ver iptables
sudo iptables -L -n
```

**Solução**:
```bash
# Permitir no firewall
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# Verificar se o container está bound no 0.0.0.0
# No docker-compose.yml:
ports:
  - "80:80"      # Correto: bind em todos interfaces
  # - "127.0.0.1:80:80"  # Errado: apenas localhost
```

---

## 🐛 Problemas com Aplicações

### Aplicação não inicia

**Diagnóstico**:
```bash
# Ver logs
docker compose logs app

# Ver motivo da saída
docker inspect <container-id> | jq '.[0].State'

# Executar comando manualmente
docker compose run --rm app sh
```

**Erros comuns**:

1. **Variáveis de ambiente faltando**:
```
Error: Missing required environment variable: DATABASE_URL
```

**Solução**: Adicionar no docker-compose.yml ou arquivo .env

2. **Porta já em uso**:
```
Error: listen EADDRINUSE: address already in use :::3000
```

**Solução**: Mudar porta no docker-compose.yml ou parar processo conflitante

3. **Dependência não disponível**:
```
Error: getaddrinfo ENOTFOUND db
```

**Solução**: Adicionar `depends_on` no docker-compose.yml

### Banco de dados não conecta

**Sintoma**: Aplicação não consegue conectar ao banco

**Soluções**:

1. **Verificar se banco está rodando**:
```bash
docker compose ps db
docker compose logs db
```

2. **Verificar credenciais**:
```bash
# Ver variáveis de ambiente
docker compose exec app env | grep DB

# Devem coincidir com as do banco
docker compose exec db env | grep POSTGRES
```

3. **Verificar host**:
```bash
# Host deve ser o nome do SERVICE do banco
# Exemplo: DB_HOST=db (não "localhost" nem "127.0.0.1")
```

4. **Testar conectividade**:
```bash
# Do app para db
docker compose exec app ping db

# Testar porta
docker compose exec app telnet db 5432
```

5. **Verificar se estão na mesma rede**:
```bash
docker inspect app | jq '.[0].NetworkSettings.Networks'
docker inspect db | jq '.[0].NetworkSettings.Networks'
```

### Dados do banco são perdidos ao reiniciar

**Causa**: Volume não configurado corretamente

**Solução**:

```yaml
# No docker-compose.yml
services:
  db:
    volumes:
      - db-data:/var/lib/postgresql/data  # Para PostgreSQL
      # - db-data:/var/lib/mysql          # Para MySQL

volumes:
  db-data:
```

**Recuperar dados** (se perdidos recentemente):

```bash
# Verificar volumes órfãos
docker volume ls

# Pode haver volumes antigos com dados
docker run --rm -v <volume-name>:/data alpine ls -la /data
```

---

## ⚡ Problemas de Performance

### Site está lento

**Diagnóstico**:

```bash
# Ver uso de recursos
docker stats

# Ver load average
uptime

# Ver I/O
iostat -x 1

# Ver logs de slow queries (se aplicável)
docker compose logs db | grep -i slow
```

**Soluções**:

1. **Nginx**:
```nginx
# Otimizações no nginx.conf
worker_processes auto;
worker_connections 2048;

# Gzip
gzip on;
gzip_comp_level 6;

# Keepalive
keepalive_timeout 65;

# Cache (para assets estáticos)
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

2. **Docker**:
```yaml
# Limitar recursos de containers problemáticos
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 1G
```

3. **PostgreSQL**:
```yaml
# Tuning PostgreSQL
environment:
  - POSTGRES_INITDB_ARGS=--data-checksums
  # Adicionar shared_buffers, etc. via config file
```

4. **Node.js**:
```yaml
# Modo cluster
command: node -r pm2 start app.js -i max
```

### VPS sem memória

**Sintoma**: Out of Memory (OOM), containers sendo killed

**Diagnóstico**:
```bash
# Ver uso de memória
free -h
docker stats --no-stream

# Ver logs do kernel
dmesg | grep -i "out of memory"
```

**Soluções**:

1. **Criar swap** (ver INSTALL.md)

2. **Limitar containers**:
```yaml
deploy:
  resources:
    limits:
      memory: 512M
```

3. **Reduzir workers do Nginx**:
```nginx
worker_processes 1;  # Ao invés de 'auto'
```

4. **Otimizar banco de dados**:
```yaml
# PostgreSQL com menos memória
environment:
  - POSTGRES_SHARED_BUFFERS=128MB
  - POSTGRES_WORK_MEM=4MB
```

### Disco cheio

**Diagnóstico**:
```bash
df -h
du -sh /var/lib/docker/*
docker system df
```

**Soluções**:

1. **Limpar Docker** (ver seção Docker acima)

2. **Limpar logs**:
```bash
# Logs do sistema
sudo journalctl --vacuum-time=7d

# Logs do Docker
sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log
```

3. **Configurar log rotation**:
```json
// /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

```bash
sudo systemctl restart docker
```

---

## 🆘 Comandos de Diagnóstico Rápido

### Checklist Geral

```bash
# 1. Containers rodando?
docker compose ps

# 2. Logs têm erros?
docker compose logs | grep -i error

# 3. Portas abertas?
sudo netstat -tulpn | grep -E '(80|443)'

# 4. Firewall configurado?
sudo ufw status

# 5. DNS correto?
dig +short seu-dominio.com

# 6. Certificado válido?
docker compose run --rm certbot certificates

# 7. Configuração Nginx válida?
docker compose exec nginx nginx -t

# 8. Recursos disponíveis?
free -h && df -h

# 9. Conectividade interna?
docker compose exec nginx ping meu-app

# 10. Tudo atualizado?
docker compose pull && docker images
```

---

## 📞 Ainda Precisa de Ajuda?

Se o problema persiste:

1. **Colete informações**:
```bash
# Criar arquivo de diagnóstico
{
    echo "=== System Info ==="
    uname -a
    echo ""
    echo "=== Docker Version ==="
    docker --version
    docker compose version
    echo ""
    echo "=== Container Status ==="
    docker compose ps
    echo ""
    echo "=== Logs ==="
    docker compose logs --tail=100
    echo ""
    echo "=== Resources ==="
    free -h
    df -h
    docker stats --no-stream
} > diagnostico.txt
```

2. **Abra uma issue** no GitHub com o arquivo `diagnostico.txt`

3. **Consulte documentação**:
   - [INSTALL.md](INSTALL.md)
   - [USAGE.md](USAGE.md)
   - [README.md](../README.md)

4. **Comunidade**:
   - [GitHub Discussions](https://github.com/seu-usuario/nginx-vps-setup/discussions)
   - [Stack Overflow](https://stackoverflow.com/questions/tagged/nginx+docker)
