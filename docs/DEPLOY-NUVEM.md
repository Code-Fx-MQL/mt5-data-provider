# MT5 local → Harnesses na nuvem

O MetaTrader 5 **só corre em Windows** com o terminal instalado. Os harnesses na nuvem (Linux/EasyPanel) **não** ligam ao MT5 diretamente — consomem a **API HTTP** do `mt5-data-provider`.

## Arquitetura

```
┌─────────────────────────────┐         HTTPS + API Key          ┌──────────────────────────┐
│  Windows (teu PC / VPS)     │  ──────────────────────────────► │  Nuvem (EasyPanel, etc.) │
│                             │                                  │                          │
│  terminal64.exe (MT5)       │                                  │  CRT Agent harness       │
│       ▲ IPC                 │                                  │  CRT_DATA_SOURCE=mt5     │
│       │                     │                                  │  MT5_PROVIDER_URL=https… │
│  mt5-data-provider :8000    │                                  └──────────────────────────┘
│  (FastAPI REST)             │
└─────────────────────────────┘
```

**Regra:** MT5 + provider ficam **num sítio com Windows**. Os harnesses na nuvem só precisam de URL pública (ou VPN) + chave API.

---

## Opção A — Túnel (recomendado para PC em casa)

Expõe `localhost:8000` sem abrir portas no router.

### Cloudflare Tunnel (grátis, HTTPS automático)

1. Instalar [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) no Windows
2. Criar túnel no dashboard Cloudflare Zero Trust
3. Configurar ingress:

```yaml
# config.yml (exemplo)
ingress:
  - hostname: mt5.seudominio.com
    service: http://localhost:8000
  - service: http_status:404
```

4. Correr:

```powershell
cloudflared tunnel run mt5-provider
```

5. No harness na nuvem (`.env` EasyPanel):

```env
CRT_DATA_SOURCE=mt5
MT5_PROVIDER_URL=https://mt5.seudominio.com
MT5_PROVIDER_API_KEY=changeme
MT5_PROVIDER_TIMEOUT_MS=60000
```

### Tailscale (rede privada — mais seguro)

1. Instalar Tailscale no Windows e nos servidores cloud (ou usar subnet router)
2. Provider continua em `http://100.x.x.x:8000` (IP Tailscale do PC)
3. Harness:

```env
MT5_PROVIDER_URL=http://100.x.x.x:8000
```

Sem expor nada à internet pública — ideal para equipas pequenas.

### ngrok (rápido para testes)

```powershell
ngrok http 8000
# URL temporária: https://xxxx.ngrok-free.app
```

---

## Opção B — Windows VPS na nuvem (produção 24/7)

Se precisas de uptime sem depender do PC:

| Provider | Notas |
|----------|-------|
| VPS Windows (Azure, OVH, Contabo…) | Instalar MT5 + provider + watchdog |
| **Não** usar EasyPanel Linux para MT5 | MT5 Python não funciona em Linux |

Fluxo:

1. VPS Windows com MT5 logado 24/7
2. `mt5-data-provider` na porta 8000
3. IIS/nginx/Caddy com HTTPS na frente
4. Firewall: só 443 (e opcionalmente IP allowlist dos teus servidores harness)

---

## Opção C — Reverse proxy na nuvem (avançado)

Um pequeno **gateway** na nuvem que autentica e reencaminha para o túnel/VPN:

```
Harness → gateway.cloud (auth) → túnel → MT5 provider local
```

Útil se tiveres vários harnesses e quiseres rate limit centralizado.

---

## Segurança obrigatória

| Medida | Config |
|--------|--------|
| API Key por harness | `MT5_API_KEYS=harness-crt:secret1,harness-bot:secret2` |
| HTTPS | Túnel Cloudflare ou certificado no proxy |
| Não expor MT5 terminal | Só a API `:8000`, nunca RDP aberto à internet sem VPN |
| Timeout cloud | `MT5_PROVIDER_TIMEOUT_MS=60000` (backtests grandes) |

Header nos harnesses:

```
X-API-Key: secret1
```

---

## Configuração harness na nuvem (CRT Agent / EasyPanel)

Em `deploy/easypanel/.env.production` ou variáveis EasyPanel:

```env
CRT_DATA_SOURCE=mt5
MT5_PROVIDER_URL=https://mt5.seudominio.com
MT5_PROVIDER_API_KEY=<mesma secret do MT5_API_KEYS>
MT5_PROVIDER_TIMEOUT_MS=60000
```

Regenerar ZIP deploy:

```powershell
.\scripts\deploy-easypanel.ps1 -AppUrl "https://fullscopetrade-harness-crt-agent.0ikuso.easypanel.host"
```

---

## Windows local — manter estável

```powershell
# Provider live
cd C:\Users\Rsantos\mt5-data-provider
Start-Process .\.venv\Scripts\python.exe -ArgumentList "-m","mt5_provider.cli" -WindowStyle Hidden

# Watchdog (tarefa a cada 2 min)
.\scripts\install-watchdog-task.ps1
```

O PC/TVPS Windows tem de estar ligado com MT5 conectado ao broker.

---

## Latência e limites

| Aspeto | Valor típico |
|--------|----------------|
| Latência ticker | 50–300 ms (túnel + rede) |
| Backtest 1500 candles | 5–15 s por par — corre no harness cloud, dados vêm do MT5 |
| Rate | Um provider serve **vários harnesses** (multi API key) |

---

## Testar ligação da nuvem

No servidor harness (ou local simulando URL pública):

```bash
curl -s https://mt5.seudominio.com/health
curl -s -H "X-API-Key: changeme" "https://mt5.seudominio.com/v1/ticker/GBPUSD"
```

No CRT Agent:

```powershell
python scripts/test-mt5-live.py
```

---

## Resumo da escolha

| Cenário | Solução |
|---------|---------|
| PC em casa, harness EasyPanel | **Cloudflare Tunnel** + API key |
| Máxima segurança, poucos servidores | **Tailscale** |
| Produção 24/7 sem PC ligado | **VPS Windows** + MT5 + provider |
| Teste rápido | **ngrok** |

O código já está pronto — falta expor o `mt5-data-provider` local com HTTPS e apontar `MT5_PROVIDER_URL` nos harnesses cloud.