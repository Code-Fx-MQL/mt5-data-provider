# MT5 Data Provider — Referência da API

Base URL local: `http://127.0.0.1:8000`  
Produção (exemplo): `https://mt5.fullscopetrade.com`

## Autenticação

Quando `MT5_API_KEYS` está configurado, **todos os endpoints `/v1/*` exigem** API key.

| Header | Valor |
|--------|-------|
| `X-API-Key` | Secret do harness (recomendado) |
| `Authorization` | `Bearer <secret>` (alternativa) |

Configuração no servidor:

```env
MT5_API_KEYS=harness-crt:secret-forte,harness-bot:outro-secret
```

No harness:

```env
MT5_PROVIDER_API_KEY=secret-forte
```

**Respostas de auth:**

| Código | Significado |
|--------|-------------|
| `401` | API key ausente ou inválida |
| `403` | — (não usado) |

Exemplo:

```bash
curl -s -H "X-API-Key: secret-forte" \
  "https://mt5.fullscopetrade.com/v1/ticker/XAUUSD"
```

---

## Endpoints públicos (sem dados sensíveis)

### `GET /health`

Health mínimo para túneis, load balancers e watchdogs.

**Auth:** não  
**Resposta:**

```json
{"status": "ok"}
```

```bash
curl -s https://mt5.fullscopetrade.com/health
```

---

### `GET /`

Metadados mínimos do serviço.

**Auth:** não  
**Resposta:**

```json
{
  "service": "mt5-data-provider",
  "version": "1.0.0",
  "api": "/v1",
  "docs": "/docs"
}
```

`docs` só aparece se `MT5_DOCS_ENABLED=true` (desativar em produção).

---

## Endpoints autenticados (`/v1/*`)

### `GET /v1/status`

Estado operacional (modo, auth, harness identificado).

```bash
curl -s -H "X-API-Key: secret-forte" \
  https://mt5.fullscopetrade.com/v1/status
```

```json
{
  "status": "ok",
  "version": "1.0.0",
  "mode": "live",
  "auth_enabled": true,
  "harness_id": "harness-crt"
}
```

---

### `GET /v1/config`

Símbolos e limites disponíveis. **Não expõe** credenciais MT5 nem `symbol_map` por defeito.

| Query | Descrição |
|-------|-----------|
| `include_internal=true` | Inclui `symbol_map` apenas se `MT5_EXPOSE_INTERNAL=true` |

```bash
curl -s -H "X-API-Key: secret-forte" \
  https://mt5.fullscopetrade.com/v1/config
```

```json
{
  "version": "1.0.0",
  "mode": "live",
  "harness_id": "harness-crt",
  "symbols": ["EURUSD", "GBPUSD", "XAUUSD"],
  "timeframes": ["1m", "5m", "15m", "30m", "1h", "4h", "1d"],
  "default_limit": 500,
  "max_limit": 3000
}
```

---

### `GET /v1/ticker/{symbol}`

Ticker estilo CCXT para um par (símbolo harness, ex. `XAUUSD`).

```bash
curl -s -H "X-API-Key: secret-forte" \
  https://mt5.fullscopetrade.com/v1/ticker/XAUUSD
```

```json
{
  "symbol": "XAUUSD",
  "timestamp": 1783640723000,
  "datetime": "2026-07-09T23:45:23+00:00",
  "bid": 4123.64,
  "ask": 4124.08,
  "last": 4123.86,
  "volume": 0.0,
  "source": "mt5"
}
```

> `mt5_symbol` (nome interno do broker) só é devolvido com `MT5_EXPOSE_INTERNAL=true`.

---

### `GET /v1/ohlcv/{symbol}`

Candles formato CCXT: `[timestamp_ms, open, high, low, close, volume]`.

| Query | Default | Descrição |
|-------|---------|-----------|
| `timeframe` | `1h` | `1m`, `5m`, `15m`, `30m`, `1h`, `4h`, `1d` |
| `limit` | `500` | Máximo conforme `MT5_MAX_LIMIT` |

```bash
curl -s -H "X-API-Key: secret-forte" \
  "https://mt5.fullscopetrade.com/v1/ohlcv/GBPUSD?timeframe=4h&limit=100"
```

```json
[
  [1783600000000, 1.3381, 1.3395, 1.3370, 1.3388, 1523.0],
  [1783614400000, 1.3388, 1.3402, 1.3380, 1.3399, 1401.0]
]
```

---

### `GET /v1/ohlcv/{symbol}/multi`

Multi-timeframe no formato consumido pelos harnesses CRT.

| Query | Default | Descrição |
|-------|---------|-----------|
| `timeframes` | `4h,1h,15m` | Lista separada por vírgula |
| `limit` | `500` | Candles por timeframe |

```bash
curl -s -H "X-API-Key: secret-forte" \
  "https://mt5.fullscopetrade.com/v1/ohlcv/XAUUSD/multi?timeframes=4h,1h,15m&limit=96"
```

```json
{
  "pair": "XAUUSD",
  "source": "mt5",
  "exchange": "mt5",
  "symbol": "XAUUSD",
  "provider": "mt5-data-provider",
  "timeframes": {
    "4h": [
      {"timestamp": 1783600000000, "open": 4110.0, "high": 4125.0, "low": 4105.0, "close": 4120.0, "volume": 800.0}
    ],
    "1h": [],
    "15m": []
  },
  "candle_counts": {"4h": 96, "1h": 96, "15m": 96}
}
```

---

### `POST /v1/ccxt/fetch_ohlcv`

RPC compatível CCXT (corpo JSON).

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -H "X-API-Key: secret-forte" \
  -d '{"pair":"EURUSD","timeframe":"1h","limit":50}' \
  https://mt5.fullscopetrade.com/v1/ccxt/fetch_ohlcv
```

```json
{
  "symbol": "EURUSD",
  "timeframe": "1h",
  "ohlcv": [[1783600000000, 1.08, 1.09, 1.07, 1.085, 900.0]]
}
```

---

## Erros

Formato consistente (sem stack traces nem códigos MT5 internos em produção):

```json
{
  "error": "SymbolNotFoundError",
  "detail": "Símbolo ou dados não disponíveis"
}
```

| HTTP | `error` | Quando |
|------|---------|--------|
| `400` | `MT5ProviderError` | Pedido inválido |
| `401` | — | Auth falhou |
| `404` | `SymbolNotFoundError` | Par/dados indisponíveis |
| `422` | `InvalidTimeframeError` | Timeframe inválido |
| `503` | `MT5ConnectionError` | MT5 offline |
| `500` | `InternalError` | Erro interno (detalhe genérico) |

Em desenvolvimento, `MT5_DEBUG_ERRORS=true` devolve mensagens completas nos logs e na resposta.

---

## Cliente Python

```python
from mt5_client import MT5DataClient

client = MT5DataClient(
    base_url="https://mt5.fullscopetrade.com",
    api_key="secret-forte",
)

# Ticker
print(client.fetch_ticker("XAUUSD"))

# OHLCV
print(client.fetch_ohlcv("GBPUSD", timeframe="4h", limit=100))

# Multi-TF (harness)
print(client.fetch_multi_tf("XAUUSD", ["4h", "1h", "15m"], limit=96))
```

Ver também: `client/mt5_client.py` e `docs/INTEGRACAO-HARNESS.md`.

---

## Integração CRT Agent

```env
CRT_DATA_SOURCE=mt5
MT5_PROVIDER_URL=https://mt5.fullscopetrade.com
MT5_PROVIDER_API_KEY=secret-forte
MT5_PROVIDER_TIMEOUT_MS=60000
```

Teste:

```powershell
cd agent-harness
python scripts/test-mt5-live.py
```

---

## Swagger / OpenAPI

Disponível apenas com `MT5_DOCS_ENABLED=true` (dev local):

- Swagger UI: http://localhost:8000/docs
- OpenAPI JSON: http://localhost:8000/openapi.json

**Em produção:** manter `MT5_DOCS_ENABLED=false`.