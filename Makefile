# Makefile para Nginx VPS Setup
# Facilita comandos comuns

.PHONY: help setup up down restart logs status ssl backup clean

# Cores para output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

help: ## Mostrar esta ajuda
	@echo "$(BLUE)Nginx VPS Setup - Comandos Disponíveis$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

setup: ## Executar setup inicial da VPS (requer root)
	@echo "$(BLUE)Executando setup inicial...$(NC)"
	@sudo ./scripts/setup.sh

up: ## Subir containers Nginx + Certbot
	@echo "$(BLUE)Subindo containers...$(NC)"
	@docker compose up -d
	@echo "$(GREEN)✓ Containers iniciados$(NC)"

down: ## Parar e remover containers
	@echo "$(YELLOW)Parando containers...$(NC)"
	@docker compose down
	@echo "$(GREEN)✓ Containers parados$(NC)"

restart: ## Reiniciar containers
	@echo "$(BLUE)Reiniciando containers...$(NC)"
	@docker compose restart
	@echo "$(GREEN)✓ Containers reiniciados$(NC)"

logs: ## Ver logs do Nginx em tempo real
	@docker compose logs -f nginx

status: ## Mostrar status de todos os containers
	@echo "$(BLUE)Status dos Containers:$(NC)"
	@docker compose ps
	@echo ""
	@echo "$(BLUE)Uso de Recursos:$(NC)"
	@docker stats --no-stream

test: ## Testar configuração do Nginx
	@echo "$(BLUE)Testando configuração Nginx...$(NC)"
	@docker compose exec nginx nginx -t
	@echo "$(GREEN)✓ Configuração válida$(NC)"

reload: ## Reload Nginx sem downtime
	@echo "$(BLUE)Recarregando Nginx...$(NC)"
	@docker compose exec nginx nginx -s reload
	@echo "$(GREEN)✓ Nginx recarregado$(NC)"

ssl: ## Obter certificado SSL (uso: make ssl DOMAIN=seu-dominio.com)
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)✗ Use: make ssl DOMAIN=seu-dominio.com$(NC)"; \
		exit 1; \
	fi
	@./scripts/get-ssl.sh $(DOMAIN)

ssl-renew: ## Renovar todos os certificados SSL
	@echo "$(BLUE)Renovando certificados SSL...$(NC)"
	@docker compose run --rm certbot renew
	@docker compose exec nginx nginx -s reload
	@echo "$(GREEN)✓ Certificados renovados$(NC)"

ssl-list: ## Listar todos os certificados SSL
	@echo "$(BLUE)Certificados SSL:$(NC)"
	@docker compose run --rm certbot certificates

backup: ## Fazer backup das configurações
	@./scripts/backup-configs.sh

add-project: ## Adicionar novo projeto (wizard interativo)
	@./scripts/add-project.sh

deploy: ## Deploy de projeto (uso: make deploy PROJECT=nome-do-projeto)
	@if [ -z "$(PROJECT)" ]; then \
		echo "$(RED)✗ Use: make deploy PROJECT=nome-do-projeto$(NC)"; \
		echo ""; \
		echo "$(BLUE)Projetos disponíveis:$(NC)"; \
		ls -1 projects | grep -v templates; \
		exit 1; \
	fi
	@./scripts/deploy.sh $(PROJECT)

update: ## Atualizar imagens Docker
	@echo "$(BLUE)Atualizando imagens...$(NC)"
	@docker compose pull
	@docker compose up -d
	@echo "$(GREEN)✓ Imagens atualizadas$(NC)"

clean: ## Limpar recursos Docker não usados
	@echo "$(YELLOW)Limpando recursos não usados...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)✓ Limpeza concluída$(NC)"

clean-all: ## Limpar TUDO (imagens, volumes, etc) - CUIDADO!
	@echo "$(RED)⚠ ATENÇÃO: Isso irá remover TODOS os recursos Docker não usados!$(NC)"
	@echo -n "Tem certeza? (s/N): "; \
	read confirm; \
	if [ "$$confirm" = "s" ] || [ "$$confirm" = "S" ]; then \
		docker system prune -a --volumes -f; \
		echo "$(GREEN)✓ Limpeza completa realizada$(NC)"; \
	else \
		echo "$(YELLOW)Operação cancelada$(NC)"; \
	fi

firewall: ## Configurar firewall (UFW)
	@echo "$(BLUE)Configurando firewall...$(NC)"
	@sudo ufw allow 22/tcp
	@sudo ufw allow 80/tcp
	@sudo ufw allow 443/tcp
	@sudo ufw --force enable
	@sudo ufw reload
	@echo "$(GREEN)✓ Firewall configurado$(NC)"

firewall-status: ## Ver status do firewall
	@sudo ufw status verbose

monitor: ## Monitorar recursos em tempo real
	@docker stats

info: ## Mostrar informações do sistema
	@echo "$(BLUE)=== Informações do Sistema ===$(NC)"
	@echo ""
	@echo "$(BLUE)Docker:$(NC)"
	@docker --version
	@docker compose version
	@echo ""
	@echo "$(BLUE)Containers:$(NC)"
	@docker compose ps
	@echo ""
	@echo "$(BLUE)Uso de Disco:$(NC)"
	@df -h /
	@echo ""
	@echo "$(BLUE)Uso de Memória:$(NC)"
	@free -h
	@echo ""
	@echo "$(BLUE)Docker Disk Usage:$(NC)"
	@docker system df

diagnose: ## Diagnóstico completo do sistema
	@echo "$(BLUE)=== Diagnóstico Completo ===$(NC)"
	@echo ""
	@echo "$(BLUE)1. Status dos Containers:$(NC)"
	@docker compose ps
	@echo ""
	@echo "$(BLUE)2. Últimos erros no Nginx:$(NC)"
	@docker compose logs nginx --tail=20 | grep -i error || echo "Nenhum erro encontrado"
	@echo ""
	@echo "$(BLUE)3. Configuração Nginx:$(NC)"
	@docker compose exec nginx nginx -t
	@echo ""
	@echo "$(BLUE)4. Portas abertas:$(NC)"
	@sudo netstat -tulpn | grep -E '(80|443)' || echo "Portas não encontradas"
	@echo ""
	@echo "$(BLUE)5. Firewall:$(NC)"
	@sudo ufw status
	@echo ""
	@echo "$(BLUE)6. Certificados SSL:$(NC)"
	@docker compose run --rm certbot certificates || echo "Nenhum certificado"
	@echo ""
	@echo "$(BLUE)7. Recursos:$(NC)"
	@free -h
	@df -h /

.DEFAULT_GOAL := help
