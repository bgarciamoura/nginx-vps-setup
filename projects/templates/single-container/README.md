# Template: Single Container

Template para aplicações simples que rodam em um único container.

## Características

- 1 container da aplicação
- Configuração minimalista
- Ideal para: APIs simples, sites estáticos, aplicações leves

## Estrutura

```
single-container/
├── docker-compose.yml
├── nginx-config-example.conf
├── Dockerfile.example
└── README.md
```

## Como Usar

1. Copie este template para o diretório do seu projeto:
   ```bash
   cp -r projects/templates/single-container projects/meu-app
   cd projects/meu-app
   ```

2. Edite o `docker-compose.yml`:
   - Altere o nome do serviço
   - Configure as variáveis de ambiente
   - Ajuste a porta interna

3. Crie seu `Dockerfile` ou use uma imagem existente

4. Copie `nginx-config-example.conf` para `nginx/conf.d/meu-app.conf` e edite:
   - Altere `server_name` para seu domínio
   - Ajuste o `proxy_pass` para o nome do serviço

5. Obtenha certificado SSL:
   ```bash
   ./scripts/get-ssl.sh meu-dominio.com
   ```

6. Deploy:
   ```bash
   docker compose up -d --build
   ```

## Exemplo de Uso

- Blog WordPress
- API REST Node.js/Python/Go
- Site estático
- Aplicação web SPA (React, Vue, Angular)
