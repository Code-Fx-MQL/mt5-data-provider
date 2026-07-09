# Modo Live — Windows + MetaTrader 5

## Pré-requisitos

1. **Windows** com MetaTrader 5 instalado
2. Terminal MT5 **aberto** e logado no broker
3. Símbolos visíveis no Market Watch (ex. XAUUSD, GBPUSD)
4. Python 3.11+

## Instalação

```powershell
cd C:\Users\Rsantos\mt5-data-provider
.\scripts\start-live.ps1
```

Ou manualmente:

```powershell
pip install -e ".[mt5]"
copy .env.example .env
# Editar .env → MT5_PROVIDER_MODE=live
mt5-provider
```

## Configuração `.env`

```env
MT5_PROVIDER_MODE=live
MT5_PATH=C:\Program Files\MetaTrader 5\terminal64.exe
MT5_API_KEYS=harness-crt:SUA_CHAVE_SECRETA
MT5_SYMBOLS=XAUUSD:XAUUSDm,GBPUSD:GBPUSDm
```

Ajuste o sufixo do broker (`XAUUSDm`, `XAUUSD.`, etc.) em **Market Watch → propriedades do símbolo**.

## Validar

```powershell
curl http://localhost:8000/health
curl http://localhost:8000/v1/ticker/XAUUSD -H "X-API-Key: SUA_CHAVE"
curl "http://localhost:8000/v1/ohlcv/XAUUSD/multi?timeframes=4h,1h,15m&limit=50" -H "X-API-Key: SUA_CHAVE"
```

## CRT Agent

No `.env` do harness:

```env
CRT_DATA_SOURCE=mt5
MT5_PROVIDER_URL=http://localhost:8000
MT5_PROVIDER_API_KEY=SUA_CHAVE_SECRETA
```

## Serviço Windows (opcional)

Use **NSSM** ou Task Scheduler para manter `mt5-provider` ativo após reinício.
O terminal MT5 deve permanecer conectado na mesma máquina.