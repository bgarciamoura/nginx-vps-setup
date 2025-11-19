# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [1.0.0] - 2025-01-19

### 🎉 Lançamento Inicial

#### Adicionado
- Configuração completa do Nginx como reverse proxy
- Suporte a SSL/TLS automático com Let's Encrypt
- Renovação automática de certificados SSL
- 3 templates de projetos:
  - Single Container (aplicações simples)
  - Load Balanced (alta disponibilidade)
  - With Database (aplicação + banco de dados)
- Scripts de automação:
  - `setup.sh` - Configuração inicial da VPS
  - `add-project.sh` - Adicionar novos projetos
  - `get-ssl.sh` - Obter certificados SSL
  - `deploy.sh` - Deploy de projetos
  - `backup-configs.sh` - Backup automático
- Documentação completa:
  - README.md - Visão geral
  - INSTALL.md - Guia de instalação
  - USAGE.md - Guia de uso
  - TROUBLESHOOTING.md - Solução de problemas
  - QUICKSTART.md - Início rápido
- Segurança integrada:
  - Firewall (UFW)
  - Fail2Ban
  - Rate limiting
  - Security headers
  - HSTS
- Configurações otimizadas do Nginx:
  - Gzip compression
  - HTTP/2
  - WebSocket support
  - SSL/TLS moderno
- Suporte a load balancing com múltiplos algoritmos
- Docker Compose para gerenciamento de containers
- Makefile com comandos úteis
- GitHub Actions para validação de configurações
- Rotação automática de logs
- Cron jobs para manutenção automática

#### Características
- ✅ Totalmente portável e versionável
- ✅ Fácil de usar e manter
- ✅ Modular e escalável
- ✅ Documentação completa em português
- ✅ Pronto para produção
- ✅ Otimizado para VPS de 1-8GB RAM
- ✅ Suporte a múltiplos projetos simultâneos

---

## [Unreleased]

### Planejado para próximas versões
- [ ] Suporte a IPv6
- [ ] Integração com Docker Swarm
- [ ] Monitoring com Prometheus + Grafana
- [ ] Suporte a HTTP/3 (QUIC)
- [ ] Templates adicionais (WordPress, Laravel, Django)
- [ ] Script de migração entre VPS
- [ ] Suporte a wildcard SSL automático
- [ ] Dashboard web para gerenciamento
- [ ] Suporte a múltiplos idiomas na documentação
- [ ] CI/CD completo com GitHub Actions

---

## Como Contribuir

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para detalhes sobre como contribuir com o projeto.

## Versionamento

- **MAJOR** (X.0.0): Mudanças incompatíveis na API
- **MINOR** (1.X.0): Novas funcionalidades compatíveis
- **PATCH** (1.0.X): Correções de bugs

---

[1.0.0]: https://github.com/seu-usuario/nginx-vps-setup/releases/tag/v1.0.0
[Unreleased]: https://github.com/seu-usuario/nginx-vps-setup/compare/v1.0.0...HEAD
