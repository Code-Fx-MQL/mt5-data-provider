"""Testes do provedor (modo stub)."""

import os

import pytest

from mt5_provider.config import get_settings
from mt5_provider.exceptions import SymbolNotFoundError
from mt5_provider.provider import MT5DataProvider
from mt5_provider.stub_backend import StubMT5Backend


@pytest.fixture(autouse=True)
def _stub_mode(monkeypatch):
    monkeypatch.setenv("MT5_PROVIDER_MODE", "stub")
    get_settings.cache_clear()


def test_fetch_ohlcv_ccxt_format():
    provider = MT5DataProvider(backend=StubMT5Backend())
    rows = provider.fetch_ohlcv("XAUUSD", "1h", limit=10)
    assert len(rows) == 10
    ts, o, h, l, c, v = rows[0]
    assert isinstance(ts, int)
    assert h >= l
    assert v >= 0


def test_fetch_multi_tf_harness_shape():
    provider = MT5DataProvider(backend=StubMT5Backend())
    data = provider.fetch_multi_tf("GBPUSD", ["4h", "1h", "15m"], limit=20)
    assert data["pair"] == "GBPUSD"
    assert data["source"] == "mt5-stub"
    assert data["exchange"] == "mt5"
    assert set(data["timeframes"]) == {"4h", "1h", "15m"}
    assert all(len(candles) == 20 for candles in data["timeframes"].values())


def test_unknown_symbol_raises():
    provider = MT5DataProvider(backend=StubMT5Backend())
    with pytest.raises(SymbolNotFoundError):
        provider.fetch_ohlcv("UNKNOWNPAIR", "1h", limit=5)