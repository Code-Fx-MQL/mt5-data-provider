"""Testes da API FastAPI."""

import os

import pytest
from fastapi.testclient import TestClient

from mt5_provider.app import app
from mt5_provider.config import get_settings


@pytest.fixture(autouse=True)
def _stub_env(monkeypatch):
    monkeypatch.setenv("MT5_PROVIDER_MODE", "stub")
    monkeypatch.setenv("MT5_API_KEYS", "")
    get_settings.cache_clear()
    import mt5_provider.app as app_module

    app_module._provider = None
    yield
    app_module._provider = None


@pytest.fixture
def client():
    return TestClient(app)


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["mode"] == "stub"


def test_ohlcv_endpoint(client):
    r = client.get("/v1/ohlcv/EURUSD", params={"timeframe": "15m", "limit": 5})
    assert r.status_code == 200
    data = r.json()
    assert len(data) == 5


def test_multi_tf_endpoint(client):
    r = client.get("/v1/ohlcv/USDCAD/multi", params={"timeframes": "1h,15m", "limit": 3})
    assert r.status_code == 200
    body = r.json()
    assert body["pair"] == "USDCAD"
    assert "1h" in body["timeframes"]


def test_api_key_required_when_configured(monkeypatch, client):
    monkeypatch.setenv("MT5_API_KEYS", "crt-agent:test-secret")
    get_settings.cache_clear()
    import mt5_provider.app as app_module

    app_module._provider = None
    client = TestClient(app)
    r = client.get("/v1/ticker/XAUUSD")
    assert r.status_code == 401
    r2 = client.get("/v1/ticker/XAUUSD", headers={"X-API-Key": "test-secret"})
    assert r2.status_code == 200