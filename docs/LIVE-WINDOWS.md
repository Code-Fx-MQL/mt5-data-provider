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

## Watchdog — monitorar e recuperar automaticamente

Dois processos precisam estar ativos:

| Processo | Função |
|----------|--------|
| `terminal64.exe` | Liga ao broker e fornece dados |
| `python -m mt5_provider.cli` | API HTTP para os harnesses |

### Verificação manual (sem reiniciar)

```powershell
.\scripts\watchdog-mt5.ps1 -DryRun
```

### Uma recuperação agora

```powershell
.\scripts\watchdog-mt5.ps1
```

Faz:
1. Verifica se o terminal em `MT5_PATH` está a correr → se não, abre
2. Verifica `http://localhost:8000/health` → se falhar, reinicia o provider
3. Testa ticker (`GBPUSD`) para confirmar dados reais
4. Regista em `logs/watchdog.log`

### Loop contínuo (terminal aberto)

```powershell
.\scripts\watchdog-mt5.ps1 -Loop -IntervalSeconds 60
```

### Tarefa Windows (a cada 2 min, recomendado)

```powershell
# PowerShell como utilizador normal
.\scripts\install-watchdog-task.ps1 -IntervalMinutes 2
```

Depois: `taskschd.msc` → tarefa **MT5-DataProvider-Watchdog**

### O que o watchdog NÃO faz

- Não faz login no broker por ti (precisas de sessão MT5 já autenticada ou credenciais no `.env`)
- Não substitui firewall/rede — se o broker desconectar, o terminal pode estar aberto mas sem dados

### Logs

```
mt5-data-provider/logs/watchdog.log
```

## Serviço Windows (opcional avançado)

Além do watchdog, podes usar **NSSM** para o provider como serviço Windows.
O terminal MT5 deve permanecer aberto na mesma máquina.