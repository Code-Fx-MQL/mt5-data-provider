"""Configuração do serviço MT5 Data Provider."""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

ProviderMode = Literal["live", "stub"]

SUPPORTED_TIMEFRAMES: tuple[str, ...] = ("1m", "5m", "15m", "30m", "1h", "4h", "1d")


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    mt5_provider_mode: ProviderMode = "stub"
    mt5_host: str = "0.0.0.0"
    mt5_port: int = Field(default=8000, ge=1024, le=65535)

    mt5_path: str | None = None
    mt5_login: int | None = None
    mt5_password: str | None = None
    mt5_server: str | None = None

    # harness_id:secret separados por vírgula
    mt5_api_keys: str = ""

    # EURUSD:EURUSDm,XAUUSD:XAUUSD
    mt5_symbols: str = (
        "XAUUSD:XAUUSD,USDCAD:USDCAD,GBPUSD:GBPUSD,EURUSD:EURUSD,"
        "US30:US30,US100:US100,NAS100:NAS100,GER40:GER40,"
        "GBPJPY:GBPJPY,AUDCAD:AUDCAD,USDCHF:USDCHF,NZDUSD:NZDUSD"
    )

    mt5_default_limit: int = Field(default=500, ge=1, le=3000)
    mt5_max_limit: int = Field(default=3000, ge=30, le=10000)

    @property
    def api_key_map(self) -> dict[str, str]:
        out: dict[str, str] = {}
        for chunk in self.mt5_api_keys.split(","):
            chunk = chunk.strip()
            if not chunk or ":" not in chunk:
                continue
            harness_id, secret = chunk.split(":", 1)
            out[secret.strip()] = harness_id.strip()
        return out

    @property
    def symbol_map(self) -> dict[str, str]:
        out: dict[str, str] = {}
        for chunk in self.mt5_symbols.split(","):
            chunk = chunk.strip()
            if not chunk or ":" not in chunk:
                continue
            harness_symbol, mt5_symbol = chunk.split(":", 1)
            out[harness_symbol.strip().upper()] = mt5_symbol.strip()
        return out

    def resolve_mt5_symbol(self, harness_symbol: str) -> str:
        key = harness_symbol.strip().upper()
        return self.symbol_map.get(key, key)

    def clamp_limit(self, limit: int | None) -> int:
        value = limit or self.mt5_default_limit
        return max(1, min(value, self.mt5_max_limit))


@lru_cache
def get_settings() -> Settings:
    return Settings()