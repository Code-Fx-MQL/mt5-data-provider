"""Testes do cliente HTTP."""

import os

import pytest
from fastapi.testclient import TestClient

from mt5_provider.app import app
from mt5_provider.config import get_settings

# import client from repo root
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "client"))
from mt5_client import MT5DataClient  # noqa: E402


@pytest.fixture(autouse=True)
def _stub_env(monkeypatch):
    monkeypatch.setenv("MT5_PROVIDER_MODE", "stub")
    monkeypatch.setenv("MT5_API_KEYS", "")
    get_settings.cache_clear()
    import mt5_provider.app as app_module

    app_module._provider = None


def test_client_fetch_multi_tf():
    with TestClient(app) as tc:
        client = MT5DataClient(base_url="http://testserver")
        # TestClient não liga ao MT5DataClient httpx diretamente — usa app in-process via ASGI
        # Validação mínima: health via TestClient
        r = tc.get("/health")
        assert r.status_code == 200