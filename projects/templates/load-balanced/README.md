# Template: Load Balanced

Template para aplicações que precisam de múltiplas réplicas para alta disponibilidade e distribuição de carga.

## Características

- 3+ réplicas do mesmo container
- Load balancing automático via Nginx
- Algoritmo: least_conn (menor número de conexões)
- Health checks passivos
- Ideal para: APIs de alta demanda, aplicações críticas

## Estrutura

```
load-balanced/
├── docker-compose.yml
├── nginx-config-example.conf
├── Dockerfile.example
└── README.md
```

## Como Usar

1. Copie este template para o diretório do seu projeto:
   ```bash
   cp -r projects/templates/load-balanced projects/minha-api
   cd projects/minha-api
   ```

2. Edite o `docker-compose.yml`:
   - Altere o nome dos serviços (app-1, app-2, app-3)
   - Configure as variáveis de ambiente
   - Ajuste o número de réplicas (adicione ou remova conforme necessário)

3. Copie `nginx-config-example.conf` para `nginx/conf.d/minha-api.conf`:
   - Altere `server_name` para seu domínio
   - Ajuste o bloco `upstream` com os nomes dos serviços
   - Configure `proxy_pass` para o upstream

4. Obtenha certificado SSL:
   ```bash
   ./scripts/get-ssl.sh meu-dominio.com
   ```

5. Deploy:
   ```bash
   docker compose up -d --build
   ```

## Algoritmos de Balanceamento

### Least Connections (padrão neste template)
```nginx
upstream backend {
    least_conn;
    server app-1:3000;
    server app-2:3000;
    server app-3:3000;
}
```
**Quando usar**: Aplicações com tempos de resposta variados.

### Round Robin
```nginx
upstream backend {
    server app-1:3000;
    server app-2:3000;
    server app-3:3000;
}
```
**Quando usar**: Requisições com tempo de processamento similar.

### IP Hash (sessões persistentes)
```nginx
upstream backend {
    ip_hash;
    server app-1:3000;
    server app-2:3000;
    server app-3:3000;
}
```
**Quando usar**: Aplicações com sessões que precisam ir sempre para o mesmo servidor.

### Weighted (servidores com capacidades diferentes)
```nginx
upstream backend {
    server app-1:3000 weight=3;
    server app-2:3000 weight=2;
    server app-3:3000 weight=1;
}
```
**Quando usar**: Servidores com diferentes capacidades de processamento.

## Escalar Dinamicamente

Para adicionar/remover réplicas sem editar o docker-compose.yml:

```bash
# Escalar para 5 réplicas
docker compose up -d --scale app=5

# Voltar para 3 réplicas
docker compose up -d --scale app=3
```

**NOTA**: Para usar `--scale`, remova `container_name` do docker-compose.yml e use apenas o nome do serviço no upstream do Nginx.

## Monitoramento

Verificar distribuição de carga:

```bash
# Fazer múltiplas requisições
for i in {1..20}; do
  curl -s https://minha-api.dominio.com/api/hostname
done

# Verificar logs
docker compose logs -f
```

## Exemplo de Uso

- APIs REST de alta demanda
- GraphQL APIs
- Microserviços críticos
- Aplicações de e-commerce
