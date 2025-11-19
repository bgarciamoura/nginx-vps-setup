# 🚀 Quick Start - Nginx VPS Setup

Guia rápido para começar em 5 minutos!

## ⚡ Setup em 3 Comandos

Na sua VPS:

```bash
# 1. Clone e entre no diretório
git clone https://github.com/seu-usuario/nginx-vps-setup.git /opt/vps && cd /opt/vps

# 2. Configure o email para SSL
cp .env.example .env && nano .env  # Edite SSL_EMAIL

# 3. Execute o setup
sudo ./scripts/setup.sh
```

Pronto! Nginx e Certbot estão rodando.

## ➕ Adicionar Primeiro Projeto

```bash
# 1. Adicionar projeto (wizard interativo)
./scripts/add-project.sh

# 2. Obter SSL
./scripts/get-ssl.sh seu-dominio.com

# 3. Adicionar seu código
cd projects/seu-projeto
# ... copie seu código, crie Dockerfile, etc.

# 4. Deploy
./scripts/deploy.sh seu-projeto
```

Acesse: `https://seu-dominio.com`

## 📂 Estrutura Rápida

```
vps/
├── nginx/conf.d/          ← Configs dos projetos
├── projects/              ← Seus projetos aqui
│   └── templates/         ← Templates prontos
├── scripts/               ← Scripts úteis
│   ├── setup.sh          ← Setup inicial
│   ├── add-project.sh    ← Adicionar projeto
│   ├── get-ssl.sh        ← Obter SSL
│   └── deploy.sh         ← Fazer deploy
└── docs/                  ← Documentação completa
```

## 🎯 Comandos Essenciais

```bash
# Ver status
docker compose ps

# Ver logs
docker compose logs -f nginx
docker compose -f projects/meu-app/docker-compose.yml logs -f

# Restart
docker compose restart nginx
./scripts/deploy.sh meu-app  # escolher opção 4

# Backup
./scripts/backup-configs.sh

# Atualizar
docker compose pull && docker compose up -d
```

## 🆘 Problemas?

```bash
# Diagnóstico rápido
docker compose ps                              # Containers rodando?
docker compose logs nginx | grep -i error      # Erros no Nginx?
sudo ufw status                                # Firewall ok?
dig +short seu-dominio.com                     # DNS correto?
```

**Docs completas**:
- 📖 [README.md](README.md) - Visão geral
- 💿 [INSTALL.md](docs/INSTALL.md) - Instalação detalhada
- 📚 [USAGE.md](docs/USAGE.md) - Guia de uso completo
- 🔧 [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Solução de problemas

## 🎨 Templates Disponíveis

### 1. Single Container (App Simples)
```bash
cp -r projects/templates/single-container projects/meu-app
```
**Ideal para**: Sites, APIs simples, SPAs

### 2. Load Balanced (Alta Disponibilidade)
```bash
cp -r projects/templates/load-balanced projects/minha-api
```
**Ideal para**: APIs críticas, microserviços

### 3. With Database (App + Banco)
```bash
cp -r projects/templates/with-database projects/meu-sistema
```
**Ideal para**: Sistemas completos, CRMs, E-commerce

## 🔐 Segurança Incluída

✅ SSL/TLS automático (Let's Encrypt)
✅ Renovação automática de certificados
✅ Firewall (UFW) configurado
✅ Fail2Ban contra ataques
✅ Rate limiting
✅ Headers de segurança
✅ HSTS preload ready

## 💡 Dicas

**Edite antes de usar**:
- `.env` - Configure seu email e domínios
- `nginx/conf.d/*.conf` - Ajuste rate limits conforme necessidade
- `docker-compose.yml` dos projetos - Configure recursos

**Monitore**:
```bash
docker stats                    # Recursos em tempo real
./scripts/backup-configs.sh    # Backup diário automático (cron)
```

**Otimize**:
- Use imagens Alpine para containers menores
- Configure limites de recursos para VPS pequenas
- Habilite cache para assets estáticos

---

**Pronto para começar? Execute `./scripts/setup.sh` e seja feliz! 🎉**
