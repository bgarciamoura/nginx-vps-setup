# 🚀 Instalação do VPS Nginx Manager

## Instalação em 3 passos

### 1️⃣ Preparar VPS

```bash
# Conectar à VPS via SSH
ssh usuario@seu-ip-vps

# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Git
sudo apt install -y git

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Reiniciar sessão
exit
# Conectar novamente
ssh usuario@seu-ip-vps
```

### 2️⃣ Instalar VPS Nginx Manager

```bash
# Clonar repositório
cd ~
git clone https://github.com/seu-usuario/vps-nginx-manager.git
cd vps-nginx-manager

# Configurar
cp .env.example .env
nano .env
```

**Configure no .env:**
```env
DOMAIN=seudominio.com
EMAIL=seu@email.com
USE_WILDCARD_SSL=true
```

### 3️⃣ Executar Setup

```bash
# Dar permissão aos scripts
chmod +x scripts/*.sh

# Executar setup
./scripts/setup.sh
```

## ✅ Verificar Instalação

```bash
# Verificar status
./scripts/list-projects.sh

# Ver logs
docker logs nginx-proxy
```

## 🎯 Primeiro Projeto

```bash
# Adicionar projeto
./scripts/add-project.sh api api-backend 4000 3

# Ir para o diretório
cd projects/api

# Configurar e subir
nano docker-compose.yml
docker-compose up -d
```

## 🔐 Configurar DNS (Hostinger)

Já que você tem wildcard configurado, não precisa fazer nada!
Se não tiver, adicione no painel da Hostinger:

```
Tipo: A
Nome: *
Valor: IP_DA_SUA_VPS
TTL: 3600
```

## 📚 Próximos Passos

- Consulte [QUICKSTART.md](QUICKSTART.md) para guia rápido
- Veja [EXAMPLES.md](EXAMPLES.md) para exemplos de projetos
- Leia [TROUBLESHOOTING.md](TROUBLESHOOTING.md) se tiver problemas

## 🆘 Ajuda

Se algo não funcionar:

1. Verifique os logs: `docker logs nginx-proxy`
2. Liste projetos: `./scripts/list-projects.sh`
3. Monitore sistema: `./scripts/monitor.sh`
4. Consulte troubleshooting: `cat TROUBLESHOOTING.md`
