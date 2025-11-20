# 🔧 Guia de Troubleshooting

Este guia contém soluções para problemas comuns.

## 🌐 Problemas de Conectividade

### Projeto não está acessível

**Sintomas:**
- Erro 502 Bad Gateway
- Erro 503 Service Unavailable
- Site não carrega

**Diagnóstico:**

```bash
# 1. Verificar se o DNS está propagado
nslookup api.seudominio.com

# 2. Verificar se Nginx está rodando
docker ps | grep nginx-proxy

# 3. Verificar se o container do projeto está rodando
docker ps | grep nome-do-projeto

# 4. Testar configuração do Nginx
docker exec nginx-proxy nginx -t

# 5. Ver logs do Nginx
docker logs nginx-proxy --tail 100

# 6. Ver logs do projeto
cd projects/nome-do-projeto
docker-compose logs --tail 100
```

**Soluções:**

```bash
# Se Nginx não está rodando
cd nginx-proxy
docker-compose up -d

# Se container do projeto não está rodando
cd projects/nome-do-projeto
docker-compose up -d

# Se configuração do Nginx tem erro
nano nginx-proxy/nginx/conf.d/projeto.conf
# Corrigir e recarregar
docker exec nginx-proxy nginx -s reload

# Verificar se container está na rede correta
docker network inspect proxy-network
```

### Erro 404 Not Found

**Causa:** Configuração do Nginx não existe ou está incorreta

**Solução:**

```bash
# Verificar se arquivo de configuração existe
ls -la nginx-proxy/nginx/conf.d/

# Se não existir, recriar
./scripts/add-project.sh nome-projeto container-name porta réplicas

# Se existir mas retorna 404, verificar server_name
cat nginx-proxy/nginx/conf.d/projeto.conf | grep server_name

# Recarregar Nginx
./scripts/reload-nginx.sh
```

## 🔐 Problemas de SSL

### Certificado não encontrado

**Sintomas:**
- Erro SSL_ERROR_HANDSHAKE_FAILURE
- Navegador mostra "Conexão não é segura"

**Diagnóstico:**

```bash
# Listar certificados
docker exec certbot certbot certificates

# Verificar se certificado existe
ls -la nginx-proxy/certbot/conf/live/
```

**Solução - Wildcard:**

```bash
# Gerar certificado wildcard
docker exec -it certbot certbot certonly \
  --manual \
  --preferred-challenges dns \
  --email seu@email.com \
  --agree-tos \
  -d "*.seudominio.com" \
  -d "seudominio.com"

# Adicionar registro TXT no DNS conforme solicitado
# Aguardar propagação (pode levar alguns minutos)
# Continuar no Certbot

# Recarregar Nginx
docker exec nginx-proxy nginx -s reload
```

**Solução - Certificado Individual:**

```bash
# Gerar certificado para subdomínio
docker exec certbot certbot certonly --webroot \
  --webroot-path /var/www/certbot \
  --email seu@email.com \
  --agree-tos \
  -d api.seudominio.com

# Recarregar Nginx
docker exec nginx-proxy nginx -s reload
```

### Certificado expirado

**Sintomas:**
- Aviso de certificado expirado no navegador

**Solução:**

```bash
# Renovar certificados
docker exec certbot certbot renew

# Forçar renovação (mesmo se não próximo do vencimento)
docker exec certbot certbot renew --force-renewal

# Recarregar Nginx
docker exec nginx-proxy nginx -s reload
```

### Erro "too many certificates already issued"

**Causa:** Let's Encrypt tem limite de 50 certificados por domínio por semana

**Solução:**

```bash
# Usar certificado wildcard em vez de individuais
./scripts/ssl-manager.sh
# Escolher opção 2 (Gerar certificado wildcard)

# Ou aguardar 7 dias para o limite resetar

# Para testes, usar staging:
docker exec certbot certbot certonly --webroot \
  --webroot-path /var/www/certbot \
  --staging \
  -d teste.seudominio.com
```

## 🐳 Problemas com Docker

### Container não inicia

**Diagnóstico:**

```bash
# Ver logs do container
cd projects/nome-projeto
docker-compose logs

# Ver status dos containers
docker-compose ps

# Inspecionar container
docker inspect nome-container
```

**Soluções comuns:**

```bash
# Porta já em uso
# Editar docker-compose.yml e usar porta diferente

# Erro de permissão em volumes
sudo chown -R $USER:$USER ./data

# Imagem não encontrada
docker-compose pull
docker-compose up -d --build

# Variável de ambiente faltando
# Adicionar no docker-compose.yml ou .env
```

### Erro "network proxy-network not found"

**Solução:**

```bash
# Criar a rede
docker network create proxy-network

# Reiniciar containers
cd projects/nome-projeto
docker-compose down
docker-compose up -d
```

### Container está rodando mas Nginx não consegue acessar

**Diagnóstico:**

```bash
# Verificar se container está na rede proxy-network
docker network inspect proxy-network

# Verificar nome do container
docker ps --format "table {{.Names}}\t{{.Networks}}"
```

**Solução:**

```bash
# Garantir que o container está na rede correta
cd projects/nome-projeto

# Adicionar network no docker-compose.yml
networks:
  proxy-network:
    external: true

# Reiniciar
docker-compose down
docker-compose up -d
```

## 🚀 Problemas de Performance

### Site muito lento

**Diagnóstico:**

```bash
# Verificar uso de recursos
docker stats

# Ver logs para identificar gargalos
docker logs nginx-proxy --tail 500 | grep -i error
```

**Soluções:**

```bash
# Adicionar mais réplicas (load balancing)
./scripts/remove-project.sh projeto
./scripts/add-project.sh projeto container-name porta 5

# Adicionar cache no Nginx
# Editar nginx-proxy/nginx/conf.d/projeto.conf

# Aumentar recursos do Docker
# Editar /etc/docker/daemon.json
```

### Alto uso de CPU/memória

**Solução:**

```bash
# Limitar recursos do container
# Adicionar no docker-compose.yml:
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M

# Limpar containers, imagens e volumes não utilizados
docker system prune -a --volumes
```

## 📝 Problemas de Configuração

### Alterações no Nginx não têm efeito

**Solução:**

```bash
# Recarregar configuração
./scripts/reload-nginx.sh

# Se ainda não funcionar, reiniciar container
docker restart nginx-proxy

# Verificar sintaxe
docker exec nginx-proxy nginx -t
```

### Scripts não executam

**Solução:**

```bash
# Dar permissão de execução
chmod +x scripts/*.sh

# Se erro de "bad interpreter"
# Converter de Windows para Unix
dos2unix scripts/*.sh
# ou
sed -i 's/\r$//' scripts/*.sh
```

## 🔍 Logs e Debugging

### Ver logs em tempo real

```bash
# Nginx
docker logs -f nginx-proxy

# Certbot
docker logs -f certbot

# Projeto específico
cd projects/nome-projeto
docker-compose logs -f

# Todos os containers
docker ps -a --format "table {{.Names}}\t{{.Status}}"
```

### Habilitar debug no Nginx

```bash
# Editar docker-compose do nginx-proxy
# Adicionar em command:
command: nginx -g 'daemon off; error_log /var/log/nginx/error.log debug;'

# Reiniciar
cd nginx-proxy
docker-compose down
docker-compose up -d

# Ver logs detalhados
docker logs nginx-proxy
```

## 💾 Problemas com Volumes

### Dados perdidos após restart

**Causa:** Volume não configurado corretamente

**Solução:**

```bash
# Verificar volumes
docker volume ls

# Adicionar volume no docker-compose.yml
volumes:
  - nome-volume:/path/no/container

volumes:
  nome-volume:
```

### Permissões negadas em volumes

**Solução:**

```bash
# Ajustar permissões
sudo chown -R $USER:$USER ./projects/nome-projeto/data

# Ou rodar container como root (não recomendado)
user: "0:0"
```

## 🌍 Problemas de DNS

### DNS não propaga

**Diagnóstico:**

```bash
# Verificar propagação
nslookup api.seudominio.com

# Usar DNS público do Google
nslookup api.seudominio.com 8.8.8.8

# Verificar online
# https://dnschecker.org
```

**Solução:**

- Aguardar propagação (pode levar até 48h, mas geralmente 5-30min)
- Verificar configuração no painel da Hostinger
- Limpar cache DNS local: `sudo systemd-resolve --flush-caches`

## 🆘 Comandos de Emergência

### Resetar tudo

```bash
# ⚠️ CUIDADO: Isso remove TUDO

# Parar todos os containers
docker stop $(docker ps -aq)

# Remover todos os containers
docker rm $(docker ps -aq)

# Remover todas as redes customizadas
docker network prune -f

# Limpar sistema
docker system prune -a --volumes

# Recriar rede
docker network create proxy-network

# Reiniciar setup
./scripts/setup.sh
```

### Backup de emergência

```bash
# Backup de certificados
tar -czf ssl-backup-$(date +%Y%m%d).tar.gz nginx-proxy/certbot/conf/

# Backup de configurações
tar -czf configs-backup-$(date +%Y%m%d).tar.gz nginx-proxy/nginx/conf.d/

# Backup de projeto
cd projects/nome-projeto
tar -czf ~/projeto-backup-$(date +%Y%m%d).tar.gz .
```

## 📞 Ainda com problemas?

1. Verifique a [documentação oficial do Nginx](https://nginx.org/en/docs/)
2. Consulte a [documentação do Docker](https://docs.docker.com/)
3. Verifique os logs: `docker logs nginx-proxy`
4. Teste a configuração: `docker exec nginx-proxy nginx -t`
5. Liste os projetos: `./scripts/list-projects.sh`

## 📋 Checklist de Diagnóstico

- [ ] DNS está configurado corretamente?
- [ ] Nginx proxy está rodando?
- [ ] Container do projeto está rodando?
- [ ] Container está na rede proxy-network?
- [ ] Configuração do Nginx está correta?
- [ ] Certificado SSL está válido?
- [ ] Firewall permite portas 80 e 443?
- [ ] Logs mostram algum erro específico?
