# Estrutura do Projeto - Nginx VPS Setup

Visão completa da organização dos arquivos e diretórios.

## 📁 Estrutura de Diretórios

```
nginx-vps-setup/
│
├── 📄 README.md                          # Visão geral do projeto
├── 📄 QUICKSTART.md                      # Guia de início rápido
├── 📄 CHANGELOG.md                       # Histórico de versões
├── 📄 LICENSE                            # Licença MIT
├── 📄 Makefile                           # Comandos úteis (make help)
│
├── 🔧 .env.example                       # Template de variáveis de ambiente
├── 🔧 .gitignore                         # Arquivos ignorados pelo Git
├── 🔧 .markdownlint.json                 # Configuração do linter de Markdown
├── 🔧 docker-compose.yml                 # Nginx + Certbot
│
├── 📂 nginx/                             # Configurações do Nginx
│   ├── nginx.conf                        # Configuração global
│   │
│   ├── conf.d/                           # Configurações por projeto
│   │   ├── .gitkeep                      # Mantém diretório no Git
│   │   └── default.conf                  # Catch-all e redirects HTTP→HTTPS
│   │
│   └── snippets/                         # Trechos reutilizáveis
│       ├── ssl-params.conf               # Parâmetros SSL/TLS
│       ├── security-headers.conf         # Headers de segurança
│       └── proxy-params.conf             # Parâmetros de proxy
│
├── 📂 projects/                          # Seus projetos
│   └── templates/                        # Templates prontos
│       │
│       ├── single-container/             # Template: App simples
│       │   ├── README.md                 # Documentação do template
│       │   ├── docker-compose.yml        # Compose do projeto
│       │   ├── nginx-config-example.conf # Config Nginx exemplo
│       │   └── Dockerfile.example        # Dockerfile exemplo
│       │
│       ├── load-balanced/                # Template: Load balancing
│       │   ├── README.md
│       │   ├── docker-compose.yml        # 3 réplicas
│       │   ├── nginx-config-example.conf # Config com upstream
│       │   └── Dockerfile.example
│       │
│       └── with-database/                # Template: App + Banco
│           ├── README.md
│           ├── docker-compose.yml        # App + PostgreSQL
│           ├── .env.example              # Variáveis do banco
│           ├── nginx-config-example.conf
│           └── Dockerfile.example
│
├── 📂 scripts/                           # Scripts de automação
│   ├── setup.sh                          # Setup inicial da VPS
│   ├── add-project.sh                    # Adicionar novo projeto
│   ├── get-ssl.sh                        # Obter certificado SSL
│   ├── deploy.sh                         # Deploy de projetos
│   └── backup-configs.sh                 # Backup de configurações
│
├── 📂 docs/                              # Documentação completa
│   ├── INSTALL.md                        # Guia de instalação
│   ├── USAGE.md                          # Guia de uso
│   └── TROUBLESHOOTING.md                # Solução de problemas
│
└── 📂 .github/                           # GitHub Actions (CI/CD)
    └── workflows/
        └── validate.yml                  # Validação automática
```

## 📊 Estatísticas do Projeto

- **Arquivos totais**: 31+ arquivos
- **Linhas de código**: ~4000+ linhas
- **Documentação**: ~15000+ palavras
- **Scripts**: 5 scripts bash
- **Templates**: 3 templates completos
- **Idioma**: Português (documentação) + Inglês (código)

## 🎯 Componentes Principais

### 1. Configurações Core

#### `docker-compose.yml`
- Serviço Nginx (reverse proxy)
- Serviço Certbot (SSL automático)
- Rede compartilhada (proxy-network)
- Volumes para certificados e logs

#### `nginx/nginx.conf`
- Configuração global otimizada
- Worker processes e connections
- Gzip compression
- Rate limiting zones
- Logs customizados

#### `nginx/snippets/`
- **ssl-params.conf**: TLS 1.2/1.3, ciphers seguros, OCSP stapling
- **security-headers.conf**: HSTS, CSP, X-Frame-Options, etc.
- **proxy-params.conf**: Headers de proxy, timeouts, WebSocket

### 2. Scripts de Automação

| Script | Função | Uso |
|--------|--------|-----|
| `setup.sh` | Configuração inicial completa | `sudo ./scripts/setup.sh` |
| `add-project.sh` | Wizard para adicionar projetos | `./scripts/add-project.sh` |
| `get-ssl.sh` | Obter certificados SSL | `./scripts/get-ssl.sh dominio.com` |
| `deploy.sh` | Deploy de projetos | `./scripts/deploy.sh nome-projeto` |
| `backup-configs.sh` | Backup automático | `./scripts/backup-configs.sh` |

### 3. Templates de Projetos

#### Single Container
- **Uso**: Aplicações simples
- **Ideal para**: APIs, sites, SPAs
- **Containers**: 1 (aplicação)

#### Load Balanced
- **Uso**: Alta disponibilidade
- **Ideal para**: APIs críticas, microserviços
- **Containers**: 3+ (réplicas da aplicação)
- **Algoritmos**: least_conn, round_robin, ip_hash

#### With Database
- **Uso**: Aplicação completa
- **Ideal para**: Sistemas, CRM, e-commerce
- **Containers**: 2 (aplicação + banco)
- **Bancos suportados**: PostgreSQL, MySQL, MongoDB, Redis

### 4. Documentação

| Arquivo | Conteúdo |
|---------|----------|
| `README.md` | Visão geral, features, início rápido |
| `QUICKSTART.md` | Setup em 3 comandos, comandos essenciais |
| `INSTALL.md` | Instalação detalhada, pré-requisitos, troubleshooting |
| `USAGE.md` | Guia completo de uso diário, workflows |
| `TROUBLESHOOTING.md` | Problemas comuns e soluções |
| `CHANGELOG.md` | Histórico de versões e mudanças |

## 🔄 Workflow de Arquivos

### Ao adicionar novo projeto:

```
1. ./scripts/add-project.sh
   ↓
2. Cria: projects/meu-app/ (do template)
   ↓
3. Cria: nginx/conf.d/meu-app.conf
   ↓
4. Reload Nginx
   ↓
5. ./scripts/get-ssl.sh dominio.com
   ↓
6. Armazena em: volume certbot-conf
   ↓
7. Atualiza: nginx/conf.d/meu-app.conf (path do certificado)
   ↓
8. ./scripts/deploy.sh meu-app
   ↓
9. Container up em: projects/meu-app/
```

## 📦 Volumes Docker Criados

```
certbot-conf        → Certificados SSL
certbot-www         → Validação ACME challenge
nginx-logs          → Logs do Nginx
<projeto>-db-data   → Dados do banco (se with-database)
```

## 🌐 Redes Docker Criadas

```
proxy-network       → Comunicação Nginx ↔ Apps (bridge)
<projeto>-internal  → Comunicação App ↔ Banco (bridge, privada)
```

## 🔐 Arquivos Sensíveis (não versionados)

```
.env                     # Variáveis de ambiente
nginx/ssl/               # Certificados temporários
certbot/                 # Certificados Let's Encrypt
letsencrypt/             # Validação ACME
logs/                    # Logs do Nginx
projects/*/node_modules  # Dependências
projects/*/.env          # Variáveis dos projetos
backups/                 # Backups (opcional)
```

## 🚀 Arquivos de Entrada

Para começar a usar, você precisa apenas de:

1. ✅ `docker-compose.yml` → Subir Nginx + Certbot
2. ✅ `.env` → Email para SSL
3. ✅ `scripts/setup.sh` → Executar setup inicial

Todo o resto é criado automaticamente pelos scripts!

## 📝 Como Personalizar

### Nginx Global
Edite: `nginx/nginx.conf`
- Worker processes
- Rate limiting
- Gzip level
- Buffer sizes

### Nginx por Projeto
Edite: `nginx/conf.d/<projeto>.conf`
- Domínio
- Proxy pass
- Rate limits específicos
- Cache

### Docker Compose
Edite: `docker-compose.yml`
- Recursos (CPU, RAM)
- Portas
- Volumes

### Scripts
Edite: `scripts/*.sh`
- Adicionar funcionalidades
- Customizar prompts
- Alterar paths padrão

## 🎨 Convenções do Projeto

### Nomenclatura
- **Diretórios**: kebab-case (`single-container`)
- **Arquivos de config**: kebab-case (` ssl-params.conf`)
- **Variáveis de ambiente**: SCREAMING_SNAKE_CASE (`SSL_EMAIL`)
- **Services Docker**: kebab-case (`nginx-proxy`)

### Estrutura de Arquivos
- Configs Nginx: sempre em `nginx/conf.d/`
- Scripts: sempre em `scripts/`
- Docs: sempre em `docs/`
- Templates: sempre em `projects/templates/`

### Comentários
- **Nginx**: `# Comentário`
- **Bash**: `# Comentário`
- **YAML**: `# Comentário`
- **Dockerfile**: `# Comentário`

## 🔍 Localização Rápida

**Precisa de:**

- Configurar SSL? → `nginx/snippets/ssl-params.conf`
- Adicionar segurança? → `nginx/snippets/security-headers.conf`
- Rate limiting? → `nginx/nginx.conf` (zones) + `nginx/conf.d/*.conf` (uso)
- Novo projeto? → `./scripts/add-project.sh`
- Deploy? → `./scripts/deploy.sh`
- Backup? → `./scripts/backup-configs.sh`
- Logs? → `docker compose logs`
- Problema? → `docs/TROUBLESHOOTING.md`
- Como usar? → `docs/USAGE.md`
- Instalar? → `docs/INSTALL.md`

---

**Dúvidas sobre a estrutura? Consulte o [README.md](README.md) ou [docs/USAGE.md](docs/USAGE.md)**
