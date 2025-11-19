# Nginx VPS Setup - Configuração Portável de Reverse Proxy com SSL

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Configuração completa, portável e versionável de Nginx como reverse proxy com SSL automático (Let's Encrypt) para VPS. Ideal para hospedar múltiplos projetos em uma única VPS com suporte a load balancing.

## 🚀 Características

- ✅ **Nginx como Reverse Proxy containerizado**
- ✅ **SSL/TLS automático** com Let's Encrypt e renovação automática
- ✅ **Load Balancing** para projetos que precisam de múltiplas réplicas
- ✅ **Segurança integrada**: Rate limiting, headers de segurança, firewall
- ✅ **Totalmente portável**: Use em qualquer VPS Linux
- ✅ **Fácil manutenção**: Scripts de automação para todas operações
- ✅ **Modular**: Adicione/remova projetos facilmente
- ✅ **Documentação completa**: Guias detalhados de instalação e uso

## 📋 Pré-requisitos

### Na VPS:
- Ubuntu 20.04+ ou Debian 10+ (outras distros Linux também funcionam)
- Docker 20.10+
- Docker Compose 2.0+
- Git
- Acesso root ou sudo

### Antes de começar:
- Domínios/subdomínios configurados apontando para o IP da VPS (registro DNS tipo A)
- Portas 80 e 443 abertas no firewall

## 🏗️ Arquitetura

```
Internet (porta 80/443)
       ↓
   [Nginx Reverse Proxy]
       ↓
   proxy-network (Docker)
       ↓
   ├── Projeto A (load balanced: 3 réplicas)
   ├── Projeto B (single container)
   ├── Projeto C (com banco de dados)
   └── ... (N projetos)

[Certbot] → Renovação SSL automática (2x/dia)
```

## 📦 Estrutura do Projeto

```
vps/
├── README.md                   # Este arquivo
├── .env.example               # Template de configuração
├── docker-compose.yml         # Nginx + Certbot
├── nginx/
│   ├── nginx.conf            # Configuração global
│   ├── conf.d/               # Configurações por projeto
│   └── snippets/             # Snippets reutilizáveis (SSL, segurança)
├── projects/
│   └── templates/            # Templates de projetos
├── scripts/
│   ├── setup.sh             # Setup inicial da VPS
│   ├── add-project.sh       # Adicionar novo projeto
│   ├── get-ssl.sh           # Obter certificado SSL
│   ├── deploy.sh            # Deploy de projeto
│   └── backup-configs.sh    # Backup de configurações
└── docs/
    ├── INSTALL.md           # Guia de instalação
    ├── USAGE.md             # Guia de uso
    └── TROUBLESHOOTING.md   # Solução de problemas
```

## 🚀 Início Rápido

### 1. Na sua VPS, clone o repositório:

```bash
cd /opt
git clone https://github.com/seu-usuario/nginx-vps-setup.git vps
cd vps
```

### 2. Configure as variáveis de ambiente:

```bash
cp .env.example .env
nano .env  # Edite com suas configurações
```

### 3. Execute o setup inicial:

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

Este script irá:
- Instalar dependências necessárias
- Criar estrutura de diretórios
- Configurar firewall (UFW)
- Criar rede Docker
- Subir Nginx + Certbot

### 4. Adicione seu primeiro projeto:

```bash
./scripts/add-project.sh
```

Siga o wizard interativo para configurar:
- Nome do projeto
- Domínio
- Porta interna
- Tipo (single, load-balanced, with-database)

### 5. Obtenha certificado SSL:

```bash
./scripts/get-ssl.sh seu-dominio.com
```

### 6. Faça deploy do seu projeto:

```bash
./scripts/deploy.sh nome-do-projeto
```

## 📚 Documentação Completa

- **[Guia de Instalação](docs/INSTALL.md)** - Instalação detalhada passo a passo
- **[Guia de Uso](docs/USAGE.md)** - Como usar todos os scripts e recursos
- **[Solução de Problemas](docs/TROUBLESHOOTING.md)** - Problemas comuns e soluções

## 🛠️ Uso Avançado

### Adicionar projeto manualmente

```bash
# 1. Criar configuração Nginx
nano nginx/conf.d/meu-app.conf

# 2. Criar docker-compose do projeto
cd projects/meu-app
nano docker-compose.yml

# 3. Obter SSL
./scripts/get-ssl.sh meu-app.dominio.com

# 4. Reload Nginx
docker compose exec nginx nginx -s reload

# 5. Deploy
docker compose -f projects/meu-app/docker-compose.yml up -d
```

### Load Balancing

Para adicionar load balancing a um projeto existente, edite a configuração Nginx:

```nginx
upstream meu-app-backend {
    least_conn;
    server meu-app-1:3000;
    server meu-app-2:3000;
    server meu-app-3:3000;
}

server {
    # ...
    location / {
        proxy_pass http://meu-app-backend;
        # ...
    }
}
```

E escale os containers:

```bash
cd projects/meu-app
docker compose up -d --scale meu-app=3
```

### Monitoramento

```bash
# Ver logs do Nginx
docker compose logs -f nginx

# Ver logs de um projeto específico
docker compose -f projects/meu-app/docker-compose.yml logs -f

# Verificar status de todos os containers
docker ps

# Ver uso de recursos
docker stats
```

## 🔒 Segurança

Este setup inclui:

- **SSL/TLS**: Apenas TLS 1.2 e 1.3
- **HSTS**: HTTP Strict Transport Security
- **Headers de segurança**: X-Frame-Options, CSP, etc.
- **Rate Limiting**: Proteção contra abuso de API
- **Firewall**: UFW configurado (apenas portas 22, 80, 443)
- **Fail2Ban**: Opcional, mas recomendado para proteção adicional

## 🔄 Manutenção

### Renovação SSL

A renovação é **automática** (2x por dia via cron). Para renovar manualmente:

```bash
docker compose run --rm certbot renew
docker compose exec nginx nginx -s reload
```

### Backup

```bash
# Backup manual
./scripts/backup-configs.sh

# Backups automáticos são configurados via cron no setup.sh
```

### Atualização

```bash
# Atualizar imagens Docker
docker compose pull
docker compose up -d

# Atualizar configurações do Git
git pull origin main
docker compose exec nginx nginx -s reload
```

## 🤝 Contribuindo

Contribuições são bem-vindas! Sinta-se à vontade para:

1. Fazer fork do projeto
2. Criar uma branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abrir um Pull Request

## 📝 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 🆘 Suporte

- **Issues**: [GitHub Issues](https://github.com/seu-usuario/nginx-vps-setup/issues)
- **Documentação**: Veja a pasta `docs/`
- **Discussões**: [GitHub Discussions](https://github.com/seu-usuario/nginx-vps-setup/discussions)

## 🌟 Agradecimentos

Desenvolvido com base nas melhores práticas de DevOps e recomendações oficiais de:
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---

**Desenvolvido com ❤️ para simplificar o deploy de múltiplas aplicações em VPS**
