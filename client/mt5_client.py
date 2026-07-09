"""Cliente HTTP para consumir o MT5 Data Provider a partir de qualquer harness."""

from __future__ import annotations

from typing import Any

import httpx


class MT5DataClient:
    """Cliente leve — mesma forma de resposta que fetch_multi_tf do CRT Agent."""

    def __init__(
        self,
        base_url: str,
        api_key: str | None = None,
        timeout: float = 30.0,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout

    def _headers(self) -> dict[str, str]:
        if not self.api_key:
            return {}
        return {"X-API-Key": self.api_key}

    def health(self) -> dict[str, Any]:
        with httpx.Client(timeout=self.timeout) as client:
            r = client.get(f"{self.base_url}/health", headers=self._headers())
            r.raise_for_status()
            return r.json()

    def fetch_ticker(self, symbol: str) -> dict[str, Any]:
        with httpx.Client(timeout=self.timeout) as client:
            r = client.get(
                f"{self.base_url}/v1/ticker/{symbol.upper()}",
                headers=self._headers(),
            )
            r.raise_for_status()
            return r.json()

    def fetch_ohlcv(
        self,
        symbol: str,
        timeframe: str = "1h",
        limit: int | None = None,
    ) -> list[list[float]]:
        params: dict[str, Any] = {"timeframe": timeframe}
        if limit is not None:
            params["limit"] = limit
        with httpx.Client(timeout=self.timeout) as client:
            r = client.get(
                f"{self.base_url}/v1/ohlcv/{symbol.upper()}",
                params=params,
                headers=self._headers(),
            )
            r.raise_for_status()
            return r.json()

    def fetch_multi_tf(
        self,
        pair: str,
        timeframes: list[str],
        limit: int | None = None,
    ) -> dict[str, Any]:
        params: dict[str, Any] = {"timeframes": ",".join(timeframes)}
        if limit is not None:
            params["limit"] = limit
        with httpx.Client(timeout=self.timeout) as client:
            r = client.get(
                f"{self.base_url}/v1/ohlcv/{pair.upper()}/multi",
                params=params,
                headers=self._headers(),
            )
            r.raise_for_status()
            return r.json()