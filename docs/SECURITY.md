# Segurança — MT5 Data Provider

## O que nunca é exposto na API

| Dado | Onde fica |
|------|-----------|
| `MT5_PASSWORD` | Apenas `.env` local (gitignored) |
| `MT5_LOGIN` / `MT5_SERVER` | Apenas `.env` local |
| API keys completas | Nunca em respostas HTTP |
| Stack traces | Apenas logs servidor (`MT5_DEBUG_ERRORS`) |
| Códigos/msgs MT5 internos | Logs servidor; resposta genérica ao cliente |
| `symbol_map` (nomes broker) | Oculto por defeito em `/v1/config` |

## Variáveis de segurança

| Variável | Produção recomendada | Descrição |
|----------|----------------------|-----------|
| `MT5_API_KEYS` | **Obrigatório** em `live` | `harness-id:secret` — uma key por harness |
| `MT5_HOST` | `127.0.0.1` | Bind local; túnel Cloudflare na frente |
| `MT5_DOCS_ENABLED` | `false` | Desativa `/docs` e `/openapi.json` |
| `MT5_DEBUG_ERRORS` | `false` | Erros genéricos ao cliente |
| `MT5_EXPOSE_INTERNAL` | `false` | Oculta `mt5_symbol` e `symbol_map` |
| `MT5_REQUIRE_AUTH` | `false` | Força auth mesmo em `stub` (CI estrito) |

### Exemplo `.env` produção (Windows + túnel)

```env
MT5_PROVIDER_MODE=live
MT5_HOST=127.0.0.1
MT5_PORT=8000
MT5_API_KEYS=harness-crt:USE-SECRET-FORTE-AQUI
MT5_DOCS_ENABLED=false
MT5_DEBUG_ERRORS=false
MT5_EXPOSE_INTERNAL=false

MT5_PATH=C:\MT5\Instances\...\terminal64.exe
MT5_LOGIN=...
MT5_PASSWORD=...
MT5_SERVER=...
```

## Endpoints e exposição

| Endpoint | Auth | Dados expostos |
|----------|------|----------------|
| `/health` | Não | Só `{"status":"ok"}` |
| `/` | Não | Nome, versão, link docs (se ativo) |
| `/v1/*` | Sim (com keys) | Dados de mercado apenas |
| `/docs` | Não* | Desativado em produção |

## Checklist deploy

- [ ] `MT5_API_KEYS` com secrets fortes (não usar `changeme`)
- [ ] `MT5_DOCS_ENABLED=false` na instância pública
- [ ] `MT5_HOST=127.0.0.1` + Cloudflare Tunnel (HTTPS)
- [ ] Firewall: porta 8000 **não** aberta na internet
- [ ] PC Windows ligado com MT5 conectado ao broker
- [ ] Rotação de API keys se comprometidas
- [ ] `deploy/cloudflare/config.yml` com tunnel ID **não** commitado (usar template)

## Harness na nuvem

O harness EasyPanel só precisa de:

```env
MT5_PROVIDER_URL=https://mt5.fullscopetrade.com
MT5_PROVIDER_API_KEY=<secret do MT5_API_KEYS>
```

Nunca configurar `MT5_PASSWORD` no harness cloud.

## Rotação de API key

1. Adicionar nova key em `MT5_API_KEYS` (ex. `harness-crt:novo-secret`)
2. Atualizar harness (`MT5_PROVIDER_API_KEY`)
3. Redeploy harness
4. Remover key antiga do provider
5. Reiniciar provider

Ver também: `docs/API.md`, `docs/DEPLOY-NUVEM.md`.