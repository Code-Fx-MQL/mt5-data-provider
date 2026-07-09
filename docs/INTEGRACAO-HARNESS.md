# Integração com projetos Harness

Repositório: https://github.com/Code-Fx-MQL/mt5-data-provider

Este serviço é **independente** dos harnesses. Cada harness consome a API via HTTP.

**CRT Agent** já integrado em `feat(data): integração MT5 Data Provider` — `CRT_DATA_SOURCE=mt5`.

## CRT Agent (exemplo)

### 1. Variáveis no `.env` do harness

```env
CRT_DATA_SOURCE=mt5
MT5_PROVIDER_URL=http://localhost:8000
MT5_PROVIDER_API_KEY=changeme
```

### 2. Provider no harness (futuro)

Criar `src/crt_agent/providers/mt5_provider.py`:

```python
from client.mt5_client import MT5DataClient  # ou pacote pip interno
from crt_agent.config.settings import settings

def fetch_multi_tf(pair: str, timeframes: list[str], limit: int | None = None):
    client = MT5DataClient(
        base_url=settings.mt5_provider_url,
        api_key=settings.mt5_provider_api_key,
    )
    return client.fetch_multi_tf(pair, timeframes, limit=limit)
```

### 3. `fetch_multi_tf_data` — adicionar modo `mt5`

Em `tools/data.py`, antes do fallback CCXT:

```python
if mode == "mt5":
    return _fetch_mt5(pair, timeframes)
```

## Multi-harness — API keys

No `.env` do **MT5 Data Provider**:

```env
MT5_API_KEYS=harness-crt:secret-crt,harness-fx:secret-fx,harness-bot:secret-bot
```

Cada harness usa a sua secret no header `X-API-Key`. O provider regista `harness_id` nos logs (futuro).

## Mapeamento de símbolos

Brokers MT5 usam sufixos diferentes (`EURUSDm`, `XAUUSD.`). Configure:

```env
MT5_SYMBOLS=XAUUSD:XAUUSDm,GBPUSD:GBPUSDm,NAS100:NAS100
```

O harness continua a pedir `XAUUSD`; o provider traduz para o símbolo MT5.

## Formato de resposta (multi-TF)

```json
{
  "pair": "XAUUSD",
  "source": "mt5",
  "exchange": "mt5",
  "symbol": "XAUUSD",
  "provider": "mt5-data-provider",
  "timeframes": {
    "4h": [{"timestamp": 1710000000000, "open": 2350.0, ...}],
    "1h": [...],
    "15m": [...]
  },
  "candle_counts": {"4h": 100, "1h": 100, "15m": 100}
}
```

Compatível com o pipeline CRT (`4h` → `1h` → `15m`).