"""Mapeamento timeframe CCXT ↔ MT5."""

from __future__ import annotations

from mt5_provider.config import SUPPORTED_TIMEFRAMES
from mt5_provider.exceptions import InvalidTimeframeError

_ALIASES: dict[str, str] = {
    "1min": "1m",
    "5min": "5m",
    "15min": "15m",
    "30min": "30m",
    "60m": "1h",
    "240m": "4h",
    "1day": "1d",
    "d1": "1d",
    "h1": "1h",
    "h4": "4h",
    "m15": "15m",
}


def normalize_timeframe(timeframe: str) -> str:
    raw = (timeframe or "1h").strip().lower()
    norm = _ALIASES.get(raw, raw)
    if norm not in SUPPORTED_TIMEFRAMES:
        raise InvalidTimeframeError(
            f"Timeframe '{timeframe}' inválido. Suportados: {', '.join(SUPPORTED_TIMEFRAMES)}"
        )
    return norm


def mt5_timeframe_constant(timeframe: str) -> int:
    import MetaTrader5 as mt5

    norm = normalize_timeframe(timeframe)
    mapping = {
        "1m": mt5.TIMEFRAME_M1,
        "5m": mt5.TIMEFRAME_M5,
        "15m": mt5.TIMEFRAME_M15,
        "30m": mt5.TIMEFRAME_M30,
        "1h": mt5.TIMEFRAME_H1,
        "4h": mt5.TIMEFRAME_H4,
        "1d": mt5.TIMEFRAME_D1,
    }
    return mapping[norm]