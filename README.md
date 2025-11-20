# VPS Nginx Manager

Gerenciador de projetos Docker com Nginx reverse proxy, SSL automático e load balancing.

## 📋 Pré-requisitos

- VPS com Ubuntu/Debian
- Docker e Docker Compose instalados
- Git instalado
- Wildcard DNS configurado (*.seudominio.com apontando para o IP da VPS)
- Portas 80 e 443 liberadas no firewall

## 🚀 Instalação

### 1. Clone este repositório na sua VPS

```bash
git clone <seu-repositorio>
cd vps-nginx-manager
```

### 2. Configure suas variáveis

Edite o arquivo `.env`:

```bash
cp .env.example .env
nano .env
```

Defina:
- `DOMAIN`: Seu domínio principal (ex: seudominio.com)
- `EMAIL`: Seu e-mail para o Let's Encrypt
- `USE_WILDCARD_SSL`: true (já que você tem wildcard configurado)

### 3. Execute o setup inicial

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

Este script irá:
- Criar a estrutura de diretórios
- Configurar a rede Docker `proxy-network`
- Subir o container do Nginx Proxy
- Configurar o Certbot para SSL
- Gerar certificado wildcard (se configurado)

## 📦 Gerenciando Projetos

### Adicionar um novo projeto

```bash
./scripts/add-project.sh
```

O script irá solicitar:
- **Nome do subdomínio** (ex: `api` para api.seudominio.com)
- **Nome do container** (ex: `api-app`)
- **Porta interna** do container (ex: `4000`)
- **Número de réplicas** para load balancing (ex: `3`)

Exemplo interativo:
```
$ ./scripts/add-project.sh
Digite o nome do subdomínio (ex: api): api
Digite o nome base do container (ex: api-app): api-app
Digite a porta interna do container (ex: 4000): 4000
Quantas réplicas para load balancing? (1-10): 3
```

Ou de forma não-interativa:
```bash
./scripts/add-project.sh api api-app 4000 3
```

### Listar projetos

```bash
./scripts/list-projects.sh
```

Mostra todos os projetos configurados com seus subdomínios e status.

### Remover um projeto

```bash
./scripts/remove-project.sh api
```

Este comando irá:
- Parar e remover containers do projeto
- Remover configuração do Nginx
- Limpar volumes (opcional)
- Recarregar Nginx

### Recarregar Nginx

Após fazer alterações manuais:

```bash
./scripts/reload-nginx.sh
```

## 📁 Estrutura de Diretórios

```
vps-nginx-manager/
├── .env                          # Configurações principais
├── .env.example                  # Exemplo de configurações
├── README.md                     # Este arquivo
├── scripts/                      # Scripts de gerenciamento
│   ├── setup.sh                 # Setup inicial
│   ├── add-project.sh           # Adicionar projeto
│   ├── remove-project.sh        # Remover projeto
│   ├── list-projects.sh         # Listar projetos
│   └── reload-nginx.sh          # Recarregar Nginx
├── nginx-proxy/                  # Nginx Reverse Proxy
│   ├── docker-compose.yml       # Compose do Nginx + Certbot
│   ├── nginx/
│   │   └── conf.d/              # Configurações dos subdomínios
│   ├── certbot/
│   │   ├── conf/                # Certificados SSL
│   │   └── www/                 # Validação ACME
│   └── ssl/
└── projects/                     # Seus projetos
    ├── api/
    │   └── docker-compose.yml
    ├── app/
    │   └── docker-compose.yml
    └── admin/
        └── docker-compose.yml
```

## 🔧 Como funciona

### 1. Nginx Proxy

O Nginx atua como reverse proxy principal, recebendo todo o tráfego HTTP/HTTPS e direcionando para os containers corretos baseado no subdomínio.

### 2. Certificados SSL

- **Com Wildcard**: Um único certificado `*.seudominio.com` cobre todos os subdomínios
- **Sem Wildcard**: Um certificado individual por subdomínio
- Renovação automática a cada 12 horas pelo Certbot

### 3. Load Balancing

Quando você configura múltiplas réplicas, o Nginx distribui o tráfego automaticamente entre elas usando a estratégia `least_conn` (menos conexões).

### 4. Rede Docker

Todos os projetos se conectam à rede `proxy-network`, permitindo que o Nginx os acesse internamente.

## 📝 Exemplo Completo

### 1. Adicionar uma API com load balancing

```bash
./scripts/add-project.sh api api-backend 4000 3
```

Isso cria:
- `nginx-proxy/nginx/conf.d/api.conf` com configuração do proxy
- `projects/api/docker-compose.yml` com 3 réplicas

### 2. Deploy do seu código

```bash
cd projects/api
# Clone seu repositório ou copie arquivos
git clone https://github.com/seu-usuario/sua-api.git .

# Edite o docker-compose.yml se necessário
nano docker-compose.yml

# Suba o projeto
docker-compose up -d
```

### 3. Verificar status

```bash
./scripts/list-projects.sh
```

### 4. Acessar

Seu projeto estará disponível em: `https://api.seudominio.com`

## 🛠️ Comandos Úteis

### Ver logs do Nginx
```bash
docker logs nginx-proxy -f
```

### Ver logs de um projeto
```bash
cd projects/api
docker-compose logs -f
```

### Verificar configuração do Nginx
```bash
docker exec nginx-proxy nginx -t
```

### Renovar certificados manualmente
```bash
docker exec certbot certbot renew
docker exec nginx-proxy nginx -s reload
```

### Listar todos os containers
```bash
docker ps
```

### Ver certificados instalados
```bash
docker exec certbot certbot certificates
```

## 🔒 Segurança

### Restringir acesso por IP

Edite o arquivo de configuração do projeto em `nginx-proxy/nginx/conf.d/seu-projeto.conf`:

```nginx
server {
    listen 443 ssl http2;
    server_name admin.seudominio.com;
    
    # Permitir apenas IPs específicos
    allow 203.0.113.0/24;
    allow 198.51.100.42;
    deny all;
    
    # ... resto da configuração
}
```

### Headers de segurança

Os templates já incluem headers básicos de segurança. Para adicionar mais:

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
```

## 🐛 Troubleshooting

### Projeto não está acessível

1. Verifique se o DNS está propagado: `nslookup seu-subdominio.seudominio.com`
2. Verifique se o container está rodando: `docker ps | grep seu-projeto`
3. Verifique os logs do Nginx: `docker logs nginx-proxy`
4. Teste a configuração: `docker exec nginx-proxy nginx -t`

### Erro de SSL

1. Verifique se o certificado foi gerado: `docker exec certbot certbot certificates`
2. Verifique os logs do Certbot: `docker logs certbot`
3. Tente renovar manualmente: `docker exec certbot certbot renew --dry-run`

### Container não conecta à rede proxy

Certifique-se de que a rede existe:
```bash
docker network ls | grep proxy-network
```

Se não existir, crie:
```bash
docker network create proxy-network
```

## 📚 Customizações Avançadas

### Alterar estratégia de load balancing

Edite o upstream no arquivo de configuração:

```nginx
upstream api_backend {
    # Opções: round_robin (padrão), least_conn, ip_hash
    ip_hash;  # Mantém sessão no mesmo servidor
    
    server api-app-1:4000;
    server api-app-2:4000;
    server api-app-3:4000;
}
```

### Adicionar cache

```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g inactive=60m;

location / {
    proxy_cache my_cache;
    proxy_cache_valid 200 60m;
    proxy_cache_key "$scheme$request_method$host$request_uri";
    
    proxy_pass http://backend;
}
```

### Rate limiting

```nginx
limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s;

location / {
    limit_req zone=mylimit burst=20 nodelay;
    proxy_pass http://backend;
}
```

## 📄 Licença

MIT License - Sinta-se livre para usar e modificar.

## 🤝 Contribuindo

Contribuições são bem-vindas! Abra uma issue ou pull request.

## 📞 Suporte

Se encontrar problemas, verifique:
1. Este README
2. Logs dos containers
3. Documentação oficial do Nginx e Docker
