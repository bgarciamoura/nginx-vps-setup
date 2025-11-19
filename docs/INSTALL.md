# Guia de Instalação - Nginx VPS Setup

Guia completo para instalar e configurar o Nginx VPS Setup em sua VPS.

## 📋 Pré-requisitos

### Sistema Operacional
- Ubuntu 20.04+ ou Debian 10+ (recomendado)
- Outras distribuições Linux também funcionam com adaptações

### Hardware Mínimo
- **RAM**: 1GB (recomendado 2GB+)
- **CPU**: 1 core (recomendado 2+ cores)
- **Disco**: 10GB livres (recomendado 20GB+)
- **Rede**: IP público fixo

### Software
- Acesso root ou sudo
- Conexão SSH configurada

### DNS
- Domínios/subdomínios configurados com registro A apontando para o IP da VPS
- Propagação DNS concluída (pode levar até 48h)

## 🚀 Instalação Rápida

### 1. Conectar na VPS via SSH

```bash
ssh root@seu-ip-da-vps
# ou
ssh usuario@seu-ip-da-vps
```

### 2. Clonar o Repositório

```bash
# Ir para diretório /opt (recomendado)
cd /opt

# Clonar repositório
git clone https://github.com/seu-usuario/nginx-vps-setup.git vps

# Entrar no diretório
cd vps
```

### 3. Configurar Variáveis de Ambiente

```bash
# Copiar template
cp .env.example .env

# Editar com seu editor favorito
nano .env
```

**Configurações importantes no `.env`:**

```bash
# Email para notificações SSL (obrigatório)
SSL_EMAIL=seu-email@dominio.com

# Domínios (opcional - pode adicionar depois)
DOMAINS="app1.dominio.com app2.dominio.com"

# Timezone
TZ=America/Sao_Paulo
```

### 4. Executar Setup

```bash
# Dar permissão de execução
chmod +x scripts/*.sh

# Executar setup (requer root)
sudo ./scripts/setup.sh
```

O script irá:
- ✅ Atualizar o sistema
- ✅ Instalar Docker e Docker Compose
- ✅ Configurar firewall (UFW)
- ✅ Configurar Fail2Ban
- ✅ Criar rede Docker
- ✅ Configurar rotação de logs
- ✅ Subir containers Nginx + Certbot
- ✅ Configurar cron para renovação SSL e backups

**Tempo estimado**: 5-10 minutos

### 5. Verificar Instalação

```bash
# Verificar containers rodando
docker compose ps

# Verificar logs
docker compose logs nginx
docker compose logs certbot

# Verificar firewall
sudo ufw status

# Testar Nginx
curl http://localhost
```

Você deve ver uma resposta 301 (redirect para HTTPS) ou 200 OK.

## 📦 Instalação Detalhada

### Instalação Manual do Docker (se necessário)

Se o script setup.sh falhar na instalação do Docker, instale manualmente:

```bash
# Remover versões antigas
sudo apt-get remove docker docker-engine docker.io containerd runc

# Instalar dependências
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Adicionar chave GPG do Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Adicionar repositório
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Iniciar Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verificar
docker --version
docker compose version
```

### Configuração Manual do Firewall

```bash
# Permitir SSH (CUIDADO: configure antes de habilitar UFW!)
sudo ufw allow 22/tcp

# Permitir HTTP e HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Habilitar firewall
sudo ufw enable

# Verificar
sudo ufw status verbose
```

### Criar Rede Docker Manualmente

```bash
docker network create proxy-network
```

### Subir Containers Manualmente

```bash
cd /opt/vps
docker compose up -d

# Verificar
docker compose ps
docker compose logs
```

## 🔧 Configuração Avançada

### Limitar Recursos dos Containers (VPS Pequena)

Edite `docker-compose.yml` e descomente:

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      memory: 256M
```

### Certificado Self-Signed Default (Opcional)

Para evitar erros quando não há certificado SSL:

```bash
mkdir -p nginx/ssl

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/default.key \
  -out nginx/ssl/default.crt \
  -subj "/C=BR/ST=State/L=City/O=Organization/CN=default"
```

Depois, descomente o bloco `default_server` no `nginx/conf.d/default.conf`.

### Gerar DH Parameters (Melhor Segurança SSL)

```bash
openssl dhparam -out nginx/dhparam.pem 2048
```

Depois, descomente no `nginx/snippets/ssl-params.conf`:

```nginx
ssl_dhparam /etc/nginx/dhparam/dhparam.pem;
```

E adicione volume no `docker-compose.yml`:

```yaml
volumes:
  - ./nginx/dhparam:/etc/nginx/dhparam:ro
```

### Configurar Swap (VPS com pouca RAM)

```bash
# Criar swap de 2GB
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Tornar permanente
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Ajustar swappiness
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## ✅ Verificação Pós-Instalação

### 1. Verificar Status dos Serviços

```bash
# Docker
sudo systemctl status docker

# Containers
docker compose ps

# Firewall
sudo ufw status

# Fail2Ban
sudo fail2ban-client status
```

### 2. Teste de Conectividade

```bash
# Testar porta 80 (HTTP)
curl -I http://seu-ip-da-vps

# Testar porta 443 (HTTPS) - após configurar SSL
curl -I https://seu-dominio.com

# Verificar portas abertas
sudo netstat -tulpn | grep -E '(80|443)'
```

### 3. Verificar Logs

```bash
# Logs do Nginx
docker compose logs nginx | tail -50

# Logs do Certbot
docker compose logs certbot | tail -50

# Logs do sistema
sudo journalctl -u docker | tail -50
```

## 🐛 Solução de Problemas

### Docker não inicia

```bash
# Verificar status
sudo systemctl status docker

# Reiniciar
sudo systemctl restart docker

# Ver logs
sudo journalctl -u docker -n 50
```

### Portas 80/443 não acessíveis

```bash
# Verificar se Nginx está rodando
docker compose ps

# Verificar firewall
sudo ufw status

# Verificar se portas estão em uso
sudo netstat -tulpn | grep -E '(80|443)'

# Testar localmente
curl http://localhost
```

### Containers não sobem

```bash
# Ver logs detalhados
docker compose logs

# Verificar se rede existe
docker network ls | grep proxy-network

# Recriar containers
docker compose down
docker compose up -d
```

### DNS não resolve

```bash
# Verificar propagação
dig seu-dominio.com
nslookup seu-dominio.com

# Verificar IP do servidor
curl ifconfig.me
```

## 🔄 Atualização

Para atualizar o setup:

```bash
cd /opt/vps

# Fazer backup antes
./scripts/backup-configs.sh

# Atualizar código
git pull origin main

# Atualizar images Docker
docker compose pull

# Recriar containers
docker compose up -d

# Verificar
docker compose ps
docker compose logs
```

## 📚 Próximos Passos

Após a instalação bem-sucedida:

1. **Adicionar primeiro projeto**: [USAGE.md](USAGE.md#adicionar-novo-projeto)
2. **Configurar SSL**: [USAGE.md](USAGE.md#obter-certificado-ssl)
3. **Deploy de aplicação**: [USAGE.md](USAGE.md#fazer-deploy)

## 🆘 Precisa de Ajuda?

- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Issues**: [GitHub Issues](https://github.com/seu-usuario/nginx-vps-setup/issues)
- **Documentação**: [README.md](../README.md)
