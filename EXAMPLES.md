# Exemplos de Docker Compose

Este arquivo contém exemplos de configuração para diferentes tipos de projeto.

## Exemplo 1: API Node.js com MongoDB (Single Instance)

```yaml
version: '3.8'

services:
  app:
    image: node:18-alpine
    container_name: api-app
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./:/app
      - /app/node_modules
    environment:
      - NODE_ENV=production
      - PORT=4000
      - MONGODB_URI=mongodb://mongodb:27017/mydb
    command: npm start
    networks:
      - proxy-network
      - internal
    depends_on:
      - mongodb

  mongodb:
    image: mongo:6
    container_name: api-mongodb
    restart: unless-stopped
    volumes:
      - mongodb-data:/data/db
    environment:
      - MONGO_INITDB_ROOT_USERNAME=admin
      - MONGO_INITDB_ROOT_PASSWORD=senha_segura
    networks:
      - internal

networks:
  proxy-network:
    external: true
  internal:
    driver: bridge

volumes:
  mongodb-data:
```

## Exemplo 2: API Node.js com Load Balancing (3 réplicas)

```yaml
version: '3.8'

services:
  app-1:
    image: node:18-alpine
    container_name: api-app-1
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./:/app
      - /app/node_modules
    environment:
      - NODE_ENV=production
      - PORT=4000
      - REDIS_URL=redis://redis:6379
    command: npm start
    networks:
      - proxy-network
      - internal

  app-2:
    image: node:18-alpine
    container_name: api-app-2
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./:/app
      - /app/node_modules
    environment:
      - NODE_ENV=production
      - PORT=4000
      - REDIS_URL=redis://redis:6379
    command: npm start
    networks:
      - proxy-network
      - internal

  app-3:
    image: node:18-alpine
    container_name: api-app-3
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./:/app
      - /app/node_modules
    environment:
      - NODE_ENV=production
      - PORT=4000
      - REDIS_URL=redis://redis:6379
    command: npm start
    networks:
      - proxy-network
      - internal

  redis:
    image: redis:alpine
    container_name: api-redis
    restart: unless-stopped
    networks:
      - internal

networks:
  proxy-network:
    external: true
  internal:
    driver: bridge
```

## Exemplo 3: Frontend React com Build

```yaml
version: '3.8'

services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    image: app-frontend:latest
    container_name: app-web
    restart: unless-stopped
    environment:
      - REACT_APP_API_URL=https://api.seudominio.com
    networks:
      - proxy-network

networks:
  proxy-network:
    external: true
```

**Dockerfile exemplo:**
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**nginx.conf exemplo:**
```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

## Exemplo 4: WordPress com MySQL

```yaml
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: blog-wordpress
    restart: unless-stopped
    environment:
      - WORDPRESS_DB_HOST=mysql
      - WORDPRESS_DB_USER=wordpress
      - WORDPRESS_DB_PASSWORD=senha_segura
      - WORDPRESS_DB_NAME=wordpress
    volumes:
      - wordpress-data:/var/www/html
    networks:
      - proxy-network
      - internal
    depends_on:
      - mysql

  mysql:
    image: mysql:8
    container_name: blog-mysql
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=root_senha
      - MYSQL_DATABASE=wordpress
      - MYSQL_USER=wordpress
      - MYSQL_PASSWORD=senha_segura
    volumes:
      - mysql-data:/var/lib/mysql
    networks:
      - internal

networks:
  proxy-network:
    external: true
  internal:
    driver: bridge

volumes:
  wordpress-data:
  mysql-data:
```

## Exemplo 5: Python FastAPI

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    image: api-fastapi:latest
    container_name: api-app
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://user:password@postgres:5432/dbname
    networks:
      - proxy-network
      - internal
    depends_on:
      - postgres

  postgres:
    image: postgres:15-alpine
    container_name: api-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=dbname
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - internal

networks:
  proxy-network:
    external: true
  internal:
    driver: bridge

volumes:
  postgres-data:
```

**Dockerfile exemplo:**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Exemplo 6: Aplicação com Health Check

```yaml
version: '3.8'

services:
  app:
    image: node:18-alpine
    container_name: api-app
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./:/app
    environment:
      - PORT=4000
    command: npm start
    networks:
      - proxy-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  proxy-network:
    external: true
```

## Dicas Importantes

1. **Sempre use a rede `proxy-network`** para que o Nginx possa acessar seu container
2. **Use redes internas** para comunicação entre containers (ex: app + database)
3. **Configure volumes** para persistir dados importantes
4. **Use health checks** para garantir que o container está saudável
5. **Defina restart policies** adequadas para seus containers
6. **Use variáveis de ambiente** para configurações sensíveis
7. **Considere usar `.env` files** para gerenciar variáveis

## Variáveis de Ambiente

Crie um arquivo `.env` no diretório do projeto:

```env
NODE_ENV=production
DATABASE_URL=postgresql://user:pass@localhost/db
API_KEY=sua_api_key_secreta
```

E referencie no docker-compose:

```yaml
services:
  app:
    env_file:
      - .env
```
