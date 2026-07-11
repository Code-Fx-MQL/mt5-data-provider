# Migração para outra máquina Windows

Guia para mover o **MT5 Data Provider** (terminal MT5 + API `:8000` + túnel Cloudflare) para um PC Windows novo, com **autoconfiguração** e arranque automático.

---

## O que precisa na nova máquina

| Componente | Obrigatório | Como instalar |
|------------|-------------|---------------|
| **Windows 10/11** | Sim | — |
| **Python 3.11+** | Sim | `winget install Python.Python.3.12` |
| **MetaTrader 5** | Sim (modo live) | Instalador do broker (Hantec, etc.) |
| **Git** | Sim (clone) | `winget install Git.Git` |
| **cloudflared** | Sim (harness na nuvem) | `winget install Cloudflare.cloudflared` |
| **Conta MT5** | Sim | Login manual no terminal (1.ª vez) |

### Dependências Python (instaladas pelo bootstrap)

```
fastapi, uvicorn, pydantic-settings, httpx, structlog
MetaTrader5, pandas  (extra [mt5])
pytest               (extra [dev])
```

Comando equivalente:

```powershell
pip install -e ".[mt5,dev]"
```

### Portas e processos

| Porta / processo | Função |
|------------------|--------|
| `127.0.0.1:8000` | API MT5 Data Provider |
| `terminal64.exe` | Terminal MT5 (dados do broker) |
| `cloudflared` | Túnel HTTPS → `https://mt5.fullscopetrade.com` |

---

## Visão geral da migração

```
MAQUINA ANTIGA                          MAQUINA NOVA
─────────────                          ────────────
1. migrate-export.ps1                  4. git clone repo
   → mt5-migration-*.zip                  C:\MT5\mt5-data-provider
2. Copiar ZIP (USB/cloud)    ───────►  5. bootstrap-windows.ps1
3. Desligar provider antigo               -MigrationZip ...
                                       6. Login MT5 (manual)
                                       7. Tarefas Windows activas
```

**Importante:** só deve haver **uma** máquina com o túnel Cloudflare activo para o mesmo hostname, senão há conflito de origem.

---

## Passo 1 — Exportar na máquina atual

```powershell
cd C:\Users\Rsantos\mt5-data-provider
.\scripts\migrate-export.ps1
```

Gera `mt5-migration-YYYYMMDD-HHmm.zip` com:

- `.env` (credenciais MT5, API keys, símbolos)
- `cloudflared/` (`config.yml`, `*.json` credenciais, `cert.pem` se existir)
- `MANIFEST.json` (metadados)

Copie o ZIP para a nova máquina (pen USB, OneDrive, etc.). **Trate o ZIP como secreto** — contém passwords MT5 e API keys.

---

## Passo 2 — Preparar a nova máquina

### 2.1 Instalar software base

```powershell
winget install Python.Python.3.12 Git.Git Cloudflare.cloudflared
```

Reinicie o PowerShell após instalar Python.

### 2.2 Instalar MetaTrader 5

1. Instale o terminal do broker (mesma conta ou nova).
2. Faça **login** e confirme símbolos no Market Watch (XAUUSD, GBPUSD, etc.).
3. Opcional: copie a instância para `C:\MT5\Instances\MT5_Conta_XXXXX\terminal64.exe` (padrão usado no `.env`).

### 2.3 Verificar dependências

```powershell
cd C:\MT5\mt5-data-provider   # após clone no passo 3
.\scripts\check-dependencies.ps1 -InstallMissing
```

---

## Passo 3 — Bootstrap automático (recomendado)

```powershell
# Clone + setup completo numa linha
powershell -ExecutionPolicy Bypass -File C:\MT5\mt5-data-provider\scripts\bootstrap-windows.ps1 `
  -MigrationZip "D:\mt5-migration-20260711-1200.zip" `
  -InstallDir "C:\MT5\mt5-data-provider" `
  -InstallDeps
```

O `bootstrap-windows.ps1`:

1. Clona o repo (se não existir)
2. Verifica/instala dependências (`check-dependencies.ps1`)
3. Importa `.env` + Cloudflare (`migrate-import.ps1`)
4. Detecta `MT5_PATH` automaticamente
5. Aplica defaults de produção (`MT5_HOST=127.0.0.1`, docs off, etc.)
6. Cria `.venv` e `pip install -e ".[mt5,dev]"`
7. Regista tarefas Windows (`install-all-tasks.ps1`)
8. Arranca watchdog MT5 + Cloudflare

### Parâmetros úteis

| Parâmetro | Descrição |
|-----------|-----------|
| `-MigrationZip` | ZIP exportado da máquina antiga |
| `-InstallDir` | Pasta destino (default `C:\MT5\mt5-data-provider`) |
| `-SkipClone` | Projeto já copiado manualmente |
| `-SkipCloudflare` | Só API local (sem túnel) |
| `-SkipTasks` | Não criar tarefas agendadas |
| `-InstallDeps` | Instalar Python/cloudflared via winget |

---

## Passo 4 — Tarefas Windows (automático)

Se não usou `-SkipTasks`, ficam criadas:

| Tarefa | Intervalo | Função |
|--------|-----------|--------|
| `MT5-DataProvider-Watchdog` | 2 min | Terminal MT5 + provider `:8000` |
| `MT5-Cloudflare-Tunnel` | 2 min + logon | Túnel HTTPS público |

Instalar manualmente:

```powershell
.\scripts\install-all-tasks.ps1
```

---

## Passo 5 — Validar

```powershell
.\scripts\watchdog-mt5.ps1 -StatusOnly
.\scripts\watchdog-cloudflare.ps1 -StatusOnly
```

```powershell
# Local
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/v1/status -H "X-API-Key: SUA_SECRET"

# Público (harness EasyPanel)
curl https://mt5.fullscopetrade.com/health
curl https://mt5.fullscopetrade.com/v1/status -H "X-API-Key: SUA_SECRET"
```

Resposta esperada: `"harness_id":"harness-crt"`.

### Harness na nuvem (CRT Agent)

**Não precisa alterar** se manteve o mesmo `MT5_API_KEYS`:

```env
MT5_PROVIDER_URL=https://mt5.fullscopetrade.com
MT5_PROVIDER_API_KEY=<mesma secret de harness-crt>
```

Se gerou nova API key na migração, atualize também no EasyPanel (`scripts/sync-mt5-api-key.py` no crt-agent).

---

## Passo 6 — Desactivar máquina antiga

1. Parar túnel: `Get-Process cloudflared | Stop-Process -Force`
2. Desactivar tarefas: `Disable-ScheduledTask -TaskName MT5-Cloudflare-Tunnel`
3. Parar provider na porta 8000
4. Confirmar que só a **nova** máquina responde em `https://mt5.fullscopetrade.com/health`

---

## Cloudflare — primeira instalação (sem migrar)

Se **não** tiver ZIP com `cloudflared/`:

```powershell
.\scripts\install-cloudflare-tunnel.ps1 -Hostname mt5.fullscopetrade.com
.\scripts\install-cloudflare-task.ps1
```

Requer `cloudflared tunnel login` e domínio no Cloudflare.

---

## Troubleshooting

| Problema | Solução |
|----------|---------|
| `IPC timeout` / `IPC initialize failed` | Terminal MT5 aberto e logado; confirme `MT5_PATH` |
| Porta 8000 em uso | Um provider já corre — `watchdog-mt5.ps1 -StatusOnly` |
| 502 em `mt5.fullscopetrade.com` | Túnel parado — `watchdog-cloudflare.ps1` ou tarefa Cloudflare |
| 401 na API | `X-API-Key` não coincide com `MT5_API_KEYS` no `.env` |
| Símbolos vazios | Ajuste `MT5_SYMBOLS` (sufixo broker: `XAUUSDm`, etc.) |
| Duas máquinas com túnel | Desligue a antiga — só uma origem por hostname |

### Logs

```
logs/watchdog.log
logs/cloudflared-watchdog.log
logs/cloudflared.err.log
```

---

## Scripts de migração (referência)

| Script | Função |
|--------|--------|
| `migrate-export.ps1` | Exporta ZIP na máquina antiga |
| `migrate-import.ps1` | Importa ZIP na máquina nova |
| `bootstrap-windows.ps1` | Setup completo automatizado |
| `check-dependencies.ps1` | Audita Python, MT5, cloudflared |
| `install-all-tasks.ps1` | Tarefas watchdog MT5 + Cloudflare |
| `watchdog-mt5.ps1` | Monitoriza terminal + provider |
| `watchdog-cloudflare.ps1` | Monitoriza túnel (lê tunnel ID do config) |

---

## Checklist rápido

- [ ] `migrate-export.ps1` na máquina antiga
- [ ] Python 3.11+, Git, cloudflared na máquina nova
- [ ] MT5 instalado e login feito
- [ ] `bootstrap-windows.ps1 -MigrationZip ... -InstallDeps`
- [ ] `watchdog-mt5.ps1 -StatusOnly` → Provider API OK
- [ ] `watchdog-cloudflare.ps1 -StatusOnly` → público OK
- [ ] `/v1/status` com API key → `harness-crt`
- [ ] Máquina antiga desactivada (túnel + provider)