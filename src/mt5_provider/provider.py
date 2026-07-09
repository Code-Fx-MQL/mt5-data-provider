"""Fachada do provedor — escolhe backend live ou stub."""

from __future__ import annotations

from typing import Any, Protocol

from mt5_provider.config import SUPPORTED_TIMEFRAMES, get_settings
from mt5_provider.live_backend import LiveMT5Backend
from mt5_provider.stub_backend import StubMT5Backend
from mt5_provider.timeframes import normalize_timeframe


class DataBackend(Protocol):
    def fetch_ticker(self, harness_symbol: str) -> dict[str, Any]: ...
    def fetch_ohlcv(self, harness_symbol: str, timeframe: str = "1h", limit: int = 500) -> list[list[float]]: ...


class MT5DataProvider:
    """Interface principal — compatível com consumo estilo CCXT."""

    def __init__(self, backend: DataBackend | None = None) -> None:
        self.settings = get_settings()
        if backend is not None:
            self._backend = backend
        elif self.settings.mt5_provider_mode == "live":
            self._backend = LiveMT5Backend()
        else:
            self._backend = StubMT5Backend()

    @property
    def mode(self) -> str:
        return self.settings.mt5_provider_mode

    def list_symbols(self) -> list[str]:
        return sorted(self.settings.symbol_map.keys())

    def list_timeframes(self) -> list[str]:
        return list(SUPPORTED_TIMEFRAMES)

    def fetch_ticker(self, symbol: str) -> dict[str, Any]:
        return self._backend.fetch_ticker(symbol)

    def fetch_ohlcv(self, symbol: str, timeframe: str = "1h", limit: int | None = None) -> list[list[float]]:
        lim = self.settings.clamp_limit(limit)
        return self._backend.fetch_ohlcv(symbol, timeframe=timeframe, limit=lim)

    def fetch_multi_tf(
        self,
        symbol: str,
        timeframes: list[str],
        limit: int | None = None,
    ) -> dict[str, Any]:
        """Formato alinhado ao fetch_multi_tf dos harnesses CRT."""
        key = symbol.strip().upper()
        lim = self.settings.clamp_limit(limit)
        mt5_symbol = self.settings.resolve_mt5_symbol(key)
        result: dict[str, Any] = {
            "pair": key,
            "source": "mt5" if self.mode == "live" else "mt5-stub",
            "exchange": "mt5",
            "symbol": mt5_symbol,
            "provider": "mt5-data-provider",
            "timeframes": {},
            "candle_counts": {},
        }
        for tf in timeframes:
            norm = normalize_timeframe(tf)
            raw = self.fetch_ohlcv(key, norm, limit=lim)
            result["timeframes"][norm] = _ohlcv_to_candles(raw)
            result["candle_counts"][norm] = len(raw)
        return result


def _ohlcv_to_candles(ohlcv: list[list[float]]) -> list[dict[str, float | int]]:
    candles: list[dict[str, float | int]] = []
    for row in ohlcv:
        ts, o, h, l, c, *rest = row
        if float(h) < float(l):
            continue
        candles.append(
            {
                "timestamp": int(ts),
                "open": float(o),
                "high": float(h),
                "low": float(l),
                "close": float(c),
                "volume": float(rest[0]) if rest else 0.0,
            }
        )
    return candles