"""Backend live — MetaTrader 5 (Windows + terminal instalado)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import structlog

from mt5_provider.config import get_settings
from mt5_provider.exceptions import MT5ConnectionError, SymbolNotFoundError
from mt5_provider.timeframes import mt5_timeframe_constant, normalize_timeframe

logger = structlog.get_logger(__name__)


class LiveMT5Backend:
    def __init__(self) -> None:
        self.settings = get_settings()
        self._connected = False

    def connect(self) -> None:
        if self._connected:
            return
        try:
            import MetaTrader5 as mt5
        except ImportError as exc:
            raise MT5ConnectionError(
                "Pacote MetaTrader5 não instalado. Use: pip install mt5-data-provider[mt5]"
            ) from exc

        creds: dict[str, Any] = {}
        if self.settings.mt5_login:
            creds["login"] = self.settings.mt5_login
        if self.settings.mt5_password:
            creds["password"] = self.settings.mt5_password
        if self.settings.mt5_server:
            creds["server"] = self.settings.mt5_server

        attempts: list[tuple[str, dict[str, Any]]] = [
            ("attach_running", {}),
            ("attach_with_creds", creds),
        ]
        if self.settings.mt5_path:
            attempts.append(("spawn_path", {"path": self.settings.mt5_path, **creds}))

        last_err: tuple[int, str] = (0, "unknown")
        for strategy, kwargs in attempts:
            if not kwargs and strategy != "attach_running":
                continue
            if mt5.initialize(**kwargs):
                self._connected = True
                logger.info("mt5_connected", strategy=strategy, terminal=mt5.terminal_info())
                return
            last_err = mt5.last_error()
            logger.warning("mt5_connect_attempt_failed", strategy=strategy, error=last_err)
            mt5.shutdown()

        code, msg = last_err
        raise MT5ConnectionError(f"Falha ao conectar MT5 ({code}): {msg}")

    def _mt5_symbol(self, harness_symbol: str) -> str:
        self.connect()
        import MetaTrader5 as mt5

        key = harness_symbol.strip().upper()
        mt5_symbol = self.settings.resolve_mt5_symbol(key)
        info = mt5.symbol_info(mt5_symbol)
        if info is None:
            raise SymbolNotFoundError(f"Símbolo MT5 '{mt5_symbol}' não encontrado para {key}")
        if not info.visible:
            mt5.symbol_select(mt5_symbol, True)
        return mt5_symbol

    def fetch_ticker(self, harness_symbol: str) -> dict[str, Any]:
        self.connect()
        import MetaTrader5 as mt5

        key = harness_symbol.strip().upper()
        mt5_symbol = self._mt5_symbol(key)
        tick = mt5.symbol_info_tick(mt5_symbol)
        if tick is None:
            raise SymbolNotFoundError(f"Tick indisponível para {mt5_symbol}")

        last = float(tick.last) if tick.last else (float(tick.bid) + float(tick.ask)) / 2
        ts = int(tick.time)
        return {
            "symbol": key,
            "mt5_symbol": mt5_symbol,
            "timestamp": ts * 1000,
            "datetime": datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(),
            "bid": float(tick.bid),
            "ask": float(tick.ask),
            "last": last,
            "volume": float(tick.volume),
            "source": "mt5",
        }

    def fetch_ohlcv(
        self,
        harness_symbol: str,
        timeframe: str = "1h",
        limit: int = 500,
    ) -> list[list[float]]:
        self.connect()
        import MetaTrader5 as mt5

        key = harness_symbol.strip().upper()
        mt5_symbol = self._mt5_symbol(key)
        tf = normalize_timeframe(timeframe)
        limit = self.settings.clamp_limit(limit)
        tf_const = mt5_timeframe_constant(tf)

        rates = mt5.copy_rates_from_pos(mt5_symbol, tf_const, 0, limit)
        if rates is None or len(rates) == 0:
            code, msg = mt5.last_error()
            raise SymbolNotFoundError(f"OHLCV vazio para {mt5_symbol} {tf} ({code}: {msg})")

        return [
            [
                int(r["time"] * 1000),
                float(r["open"]),
                float(r["high"]),
                float(r["low"]),
                float(r["close"]),
                float(r["tick_volume"]),
            ]
            for r in rates
        ]