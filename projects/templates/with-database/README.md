# Template: With Database

Template para aplicações que precisam de banco de dados integrado.

## Características

- 1 container da aplicação
- 1 container do banco de dados (PostgreSQL como exemplo)
- Rede interna isolada para comunicação app-database
- Volumes para persistência de dados
- Ideal para: Aplicações full-stack, APIs com banco próprio

## Estrutura

```
with-database/
├── docker-compose.yml
├── nginx-config-example.conf
├── Dockerfile.example
├── .env.example
└── README.md
```

## Como Usar

1. Copie este template para o diretório do seu projeto:
   ```bash
   cp -r projects/templates/with-database projects/meu-sistema
   cd projects/meu-sistema
   ```

2. Configure variáveis de ambiente:
   ```bash
   cp .env.example .env
   nano .env  # Edite com suas configurações
   ```

3. Edite o `docker-compose.yml`:
   - Altere nomes dos serviços
   - Configure credenciais do banco (use variáveis de ambiente!)
   - Escolha o banco de dados (PostgreSQL, MySQL, MongoDB, etc.)

4. Copie `nginx-config-example.conf` para `nginx/conf.d/meu-sistema.conf`

5. Obtenha certificado SSL:
   ```bash
   ./scripts/get-ssl.sh meu-dominio.com
   ```

6. Deploy:
   ```bash
   docker compose up -d --build
   ```

## Bancos de Dados Suportados

### PostgreSQL (padrão neste template)
```yaml
db:
  image: postgres:15-alpine
  environment:
    - POSTGRES_DB=myapp
    - POSTGRES_USER=myuser
    - POSTGRES_PASSWORD=secure-password
```

### MySQL/MariaDB
```yaml
db:
  image: mysql:8.0
  environment:
    - MYSQL_DATABASE=myapp
    - MYSQL_USER=myuser
    - MYSQL_PASSWORD=secure-password
    - MYSQL_ROOT_PASSWORD=root-password
```

### MongoDB
```yaml
db:
  image: mongo:6
  environment:
    - MONGO_INITDB_ROOT_USERNAME=admin
    - MONGO_INITDB_ROOT_PASSWORD=secure-password
    - MONGO_INITDB_DATABASE=myapp
```

### Redis
```yaml
cache:
  image: redis:7-alpine
  command: redis-server --requirepass secure-password
```

## Backup do Banco de Dados

### PostgreSQL
```bash
# Backup
docker compose exec db pg_dump -U myuser myapp > backup.sql

# Restore
docker compose exec -T db psql -U myuser myapp < backup.sql
```

### MySQL
```bash
# Backup
docker compose exec db mysqldump -u myuser -p myapp > backup.sql

# Restore
docker compose exec -T db mysql -u myuser -p myapp < backup.sql
```

### MongoDB
```bash
# Backup
docker compose exec db mongodump --uri="mongodb://admin:password@localhost/myapp" --out=/backup

# Restore
docker compose exec db mongorestore --uri="mongodb://admin:password@localhost/myapp" /backup/myapp
```

## Segurança

**⚠️ IMPORTANTE**:

1. **NUNCA** exponha a porta do banco diretamente (não use `ports:` no serviço do BD)
2. Use senhas fortes e armazene em variáveis de ambiente (arquivo `.env`)
3. O `.env` está no `.gitignore` - NUNCA versione senhas!
4. Faça backups regulares dos dados
5. Use volumes nomeados para persistência

## Migrações de Banco

Adicione um serviço de migração (exemplo com Node.js):

```yaml
migrations:
  image: seu-usuario/sua-imagem:latest
  command: npm run migrate
  depends_on:
    - db
  networks:
    - internal
  environment:
    - DATABASE_URL=postgresql://user:pass@db:5432/myapp
```

Execute uma vez:
```bash
docker compose run --rm migrations
```

## Monitoramento

### Ver logs do banco
```bash
docker compose logs -f db
```

### Conectar ao banco (debug)
```bash
# PostgreSQL
docker compose exec db psql -U myuser -d myapp

# MySQL
docker compose exec db mysql -u myuser -p myapp

# MongoDB
docker compose exec db mongosh -u admin -p
```

### Verificar uso de espaço
```bash
docker system df -v
```

## Exemplo de Uso

- Sistema de gerenciamento
- E-commerce
- Blog dinâmico
- CRM/ERP
- API com dados persistentes
