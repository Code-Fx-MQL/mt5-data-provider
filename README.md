# MT5 Data Provider

Provedor de dados **proprietário** baseado em MetaTrader 5, com API REST compatível com o formato **CCXT**, pensado para servir **múltiplos projetos Harness** (CRT Agent, futuros harnesses, etc.).

## Características

- API REST (`FastAPI`) com endpoints `ticker`, `ohlcv` e `multi-timeframe`
- Formato OHLCV CCXT: `[timestamp_ms, open, high, low, close, volume]`
- Resposta `fetch_multi_tf` alinhada ao CRT Agent (`pair`, `source`, `timeframes`, `candle_counts`)
- **Auth por API key** — uma chave por harness (`X-API-Key`)
- Modo **`stub`** para dev/CI sem terminal MT5
- Modo **`live`** para Windows com MetaTrader 5 instalado

## Requisitos

| Modo | Requisito |
|------|-----------|
| `stub` | Python 3.11+ |
| `live` | Windows + terminal MT5 + `pip install mt5-data-provider[mt5]` |

## Instalação

```powershell
cd C:\Users\Rsantos\mt5-data-provider
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e ".[dev]"

# Produção com MT5 real (Windows)
pip install -e ".[mt5,dev]"
```

## Configuração

```powershell
copy .env.example .env
```

| Variável | Descrição |
|----------|-----------|
| `MT5_PROVIDER_MODE` | `stub` ou `live` |
| `MT5_API_KEYS` | `harness-id:secret,harness2:secret2` |
| `MT5_SYMBOLS` | Mapeamento `HARNESS:MT5` (ex. `XAUUSD:XAUUSD`) |
| `MT5_PORT` | Porta HTTP (default `8000`) |

## Executar

```powershell
# Dev (stub)
$env:MT5_PROVIDER_MODE = "stub"
mt5-provider

# Ou
python -m mt5_provider.cli
```

Documentação interativa (dev): http://localhost:8000/docs (`MT5_DOCS_ENABLED=true`)

## Documentação

| Doc | Conteúdo |
|-----|----------|
| **[docs/MIGRACAO-WINDOWS.md](docs/MIGRACAO-WINDOWS.md)** | **Migrar para outro PC Windows** — export, bootstrap, tarefas |
| **[docs/API.md](docs/API.md)** | Referência completa — auth, endpoints, exemplos curl/Python |
| **[docs/SECURITY.md](docs/SECURITY.md)** | Checklist produção, variáveis seguras, rotação de keys |
| **[docs/INTEGRACAO-HARNESS.md](docs/INTEGRACAO-HARNESS.md)** | Ligação CRT Agent / multi-harness |
| **[docs/DEPLOY-NUVEM.md](docs/DEPLOY-NUVEM.md)** | Cloudflare Tunnel, EasyPanel |
| **[docs/LIVE-WINDOWS.md](docs/LIVE-WINDOWS.md)** | Modo live + watchdog |

### Migrar para nova máquina (resumo)

```powershell
# Maquina ANTIGA
.\scripts\migrate-export.ps1

# Maquina NOVA
winget install Python.Python.3.12 Git.Git Cloudflare.cloudflared
.\scripts\bootstrap-windows.ps1 -MigrationZip "D:\mt5-migration-....zip" -InstallDeps
```

## Endpoints (resumo)

| Método | Path | Auth | Descrição |
|--------|------|------|-----------|
| GET | `/health` | Não | Health mínimo `{"status":"ok"}` |
| GET | `/v1/status` | Sim* | Modo, versão, harness_id |
| GET | `/v1/config` | Sim* | Símbolos, timeframes, limites |
| GET | `/v1/ticker/{symbol}` | Sim* | Ticker estilo CCXT |
| GET | `/v1/ohlcv/{symbol}` | Sim* | OHLCV (`timeframe`, `limit`) |
| GET | `/v1/ohlcv/{symbol}/multi` | Sim* | Multi-TF para harness |
| POST | `/v1/ccxt/fetch_ohlcv` | Sim* | RPC compatível CCXT |

\* Quando `MT5_API_KEYS` está configurado.

### Exemplos rápidos

```powershell
curl http://127.0.0.1:8000/health
curl -H "X-API-Key: changeme" "http://127.0.0.1:8000/v1/ohlcv/XAUUSD?timeframe=4h&limit=100"
curl -H "X-API-Key: changeme" "http://127.0.0.1:8000/v1/ohlcv/GBPUSD/multi?timeframes=4h,1h,15m&limit=96"
```

Ver exemplos completos em **[docs/API.md](docs/API.md)**.

## Cliente Python (harnesses)

```python
from mt5_client import MT5DataClient

client = MT5DataClient(
    base_url="http://localhost:8000",
    api_key="changeme",
)
data = client.fetch_multi_tf("XAUUSD", ["4h", "1h", "15m"], limit=100)
# Mesmo formato que crt_agent.providers.ccxt_provider.fetch_multi_tf
```

Ver `docs/INTEGRACAO-HARNESS.md` para integrar no CRT Agent.

## Testes

```powershell
pytest -q
```

## Arquitetura

```
mt5-data-provider/
├── src/mt5_provider/     # Serviço FastAPI + backends live/stub
├── client/mt5_client.py    # Cliente HTTP para harnesses
├── tests/
└── docs/
```

## Deploy

- **Live MT5:** correr em máquina/servidor **Windows** com terminal MT5 aberto ou serviço dedicado
- **Stub:** pode correr em Linux/Docker para ambientes de teste
- Expor atrás de reverse proxy (HTTPS) e restringir por API key

### Harnesses na nuvem (MT5 local → API remota)

O MT5 fica no **Windows local**; harnesses Linux/EasyPanel consomem só HTTP:

```env
MT5_PROVIDER_URL=https://mt5.seudominio.com
MT5_PROVIDER_API_KEY=sua-chave
```

Guia completo: **[docs/DEPLOY-NUVEM.md](docs/DEPLOY-NUVEM.md)** (Cloudflare Tunnel, Tailscale, VPS Windows).

## Repositório

https://github.com/Code-Fx-MQL/mt5-data-provider

## Licença

Uso proprietário — projetos Harness FullScope Trade.