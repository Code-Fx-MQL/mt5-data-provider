"""Backend stub — desenvolvimento e testes sem terminal MT5."""

from __future__ import annotations

import hashlib
import time
from datetime import datetime, timezone
from typing import Any

from mt5_provider.config import SUPPORTED_TIMEFRAMES, get_settings
from mt5_provider.exceptions import SymbolNotFoundError
from mt5_provider.timeframes import normalize_timeframe

_STUB_BASE: dict[str, float] = {
    "XAUUSD": 2350.0,
    "USDCAD": 1.3600,
    "GBPUSD": 1.2700,
    "EURUSD": 1.0850,
    "USDCHF": 0.8800,
    "US30": 42000.0,
    "US100": 21000.0,
    "NAS100": 21000.0,
    "GER40": 18000.0,
    "GBPJPY": 195.50,
    "AUDCAD": 0.9000,
    "NZDUSD": 0.6000,
}

_TF_SECONDS: dict[str, int] = {
    "1m": 60,
    "5m": 300,
    "15m": 900,
    "30m": 1800,
    "1h": 3600,
    "4h": 14400,
    "1d": 86400,
}


def _tick_size(pair: str, base: float) -> float:
    p = pair.upper()
    if "XAU" in p:
        return 0.10
    if base >= 1000:
        return max(base * 0.0001, 1.0)
    if "JPY" in p:
        return 0.01
    return 0.0001


class StubMT5Backend:
    """Gera OHLCV determinístico por par/timeframe."""

    def __init__(self) -> None:
        self.settings = get_settings()

    def ensure_symbol(self, harness_symbol: str) -> str:
        key = harness_symbol.strip().upper()
        mt5_symbol = self.settings.resolve_mt5_symbol(key)
        if key not in self.settings.symbol_map and key not in _STUB_BASE:
            raise SymbolNotFoundError(f"Símbolo {harness_symbol} não configurado")
        return mt5_symbol

    def fetch_ticker(self, harness_symbol: str) -> dict[str, Any]:
        key = harness_symbol.strip().upper()
        mt5_symbol = self.ensure_symbol(key)
        base = _STUB_BASE.get(key, 1.0)
        tick = _tick_size(key, base)
        now = int(time.time())
        bid = base - tick
        ask = base + tick
        return {
            "symbol": key,
            "mt5_symbol": mt5_symbol,
            "timestamp": now * 1000,
            "datetime": datetime.fromtimestamp(now, tz=timezone.utc).isoformat(),
            "bid": bid,
            "ask": ask,
            "last": base,
            "volume": 1000.0,
            "source": "stub",
        }

    def fetch_ohlcv(
        self,
        harness_symbol: str,
        timeframe: str = "1h",
        limit: int = 500,
    ) -> list[list[float]]:
        key = harness_symbol.strip().upper()
        self.ensure_symbol(key)
        tf = normalize_timeframe(timeframe)
        limit = self.settings.clamp_limit(limit)
        base = _STUB_BASE.get(key, 1.0)
        tick = _tick_size(key, base)
        step = _TF_SECONDS[tf]
        now = int(time.time())
        aligned = now - (now % step)
        seed = int(hashlib.md5(f"{key}:{tf}".encode()).hexdigest()[:8], 16)

        rows: list[list[float]] = []
        for i in range(limit):
            ts = aligned - (limit - 1 - i) * step
            wave = ((seed + i) % 17) - 8
            mid = base + wave * tick
            o = mid - tick
            h = mid + tick * 2
            l = mid - tick * 2
            c = mid + tick * 0.5
            rows.append([ts * 1000, float(o), float(h), float(l), float(c), 1000.0])
        return rows