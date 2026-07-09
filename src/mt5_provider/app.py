"""FastAPI — MT5 Data Provider REST API."""

from __future__ import annotations

from contextlib import asynccontextmanager
from typing import Annotated, Any

import structlog
from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.responses import JSONResponse

from mt5_provider import __version__
from mt5_provider.auth import resolve_harness_id
from mt5_provider.config import SUPPORTED_TIMEFRAMES, get_settings
from mt5_provider.exceptions import (
    InvalidTimeframeError,
    MT5ConnectionError,
    MT5ProviderError,
    SymbolNotFoundError,
)
from mt5_provider.provider import MT5DataProvider

logger = structlog.get_logger(__name__)

_provider: MT5DataProvider | None = None


@asynccontextmanager
async def lifespan(_app: FastAPI):
    global _provider
    settings = get_settings()
    _provider = MT5DataProvider()
    if settings.mt5_provider_mode == "live":
        try:
            _provider._backend.connect()  # noqa: SLF001
            logger.info("mt5_live_startup_ok")
        except MT5ConnectionError as exc:
            logger.warning("mt5_live_startup_failed", error=str(exc))
    yield
    _provider = None


app = FastAPI(
    title="MT5 Data Provider",
    description="Provedor de dados proprietário MT5 — API compatível CCXT para projetos Harness",
    version=__version__,
    lifespan=lifespan,
)


def get_provider() -> MT5DataProvider:
    global _provider
    if _provider is None:
        _provider = MT5DataProvider()
    return _provider


@app.exception_handler(MT5ProviderError)
async def provider_error_handler(_request: Any, exc: MT5ProviderError) -> JSONResponse:
    code = status.HTTP_400_BAD_REQUEST
    if isinstance(exc, MT5ConnectionError):
        code = status.HTTP_503_SERVICE_UNAVAILABLE
    elif isinstance(exc, SymbolNotFoundError):
        code = status.HTTP_404_NOT_FOUND
    elif isinstance(exc, InvalidTimeframeError):
        code = status.HTTP_422_UNPROCESSABLE_ENTITY
    return JSONResponse(status_code=code, content={"error": exc.__class__.__name__, "detail": str(exc)})


@app.get("/health")
async def health() -> dict[str, Any]:
    settings = get_settings()
    return {
        "status": "ok",
        "version": __version__,
        "mode": settings.mt5_provider_mode,
        "auth_enabled": bool(settings.api_key_map),
    }


@app.get("/")
async def root() -> dict[str, Any]:
    settings = get_settings()
    return {
        "service": "mt5-data-provider",
        "version": __version__,
        "mode": settings.mt5_provider_mode,
        "docs": "/docs",
        "endpoints": {
            "health": "/health",
            "config": "/v1/config",
            "ticker": "/v1/ticker/{symbol}",
            "ohlcv": "/v1/ohlcv/{symbol}?timeframe=1h&limit=500",
            "multi_tf": "/v1/ohlcv/{symbol}/multi?timeframes=4h,1h,15m",
            "ccxt_rpc": "POST /v1/ccxt/fetch_ohlcv",
        },
    }


@app.get("/v1/config")
async def get_config(
    harness_id: Annotated[str | None, Depends(resolve_harness_id)],
    provider: Annotated[MT5DataProvider, Depends(get_provider)],
) -> dict[str, Any]:
    settings = get_settings()
    return {
        "version": __version__,
        "mode": provider.mode,
        "harness_id": harness_id,
        "symbols": provider.list_symbols(),
        "symbol_map": settings.symbol_map,
        "timeframes": list(SUPPORTED_TIMEFRAMES),
        "default_limit": settings.mt5_default_limit,
        "max_limit": settings.mt5_max_limit,
    }


@app.get("/v1/ticker/{symbol}")
async def get_ticker(
    symbol: str,
    _harness_id: Annotated[str | None, Depends(resolve_harness_id)],
    provider: Annotated[MT5DataProvider, Depends(get_provider)],
) -> dict[str, Any]:
    return provider.fetch_ticker(symbol)


@app.get("/v1/ohlcv/{symbol}")
async def get_ohlcv(
    symbol: str,
    timeframe: str = Query(default="1h"),
    limit: int | None = Query(default=None, ge=1, le=10000),
    _harness_id: Annotated[str | None, Depends(resolve_harness_id)] = None,
    provider: Annotated[MT5DataProvider, Depends(get_provider)] = None,
) -> list[list[float]]:
    return provider.fetch_ohlcv(symbol, timeframe=timeframe, limit=limit)


@app.get("/v1/ohlcv/{symbol}/multi")
async def get_ohlcv_multi(
    symbol: str,
    timeframes: str = Query(default="4h,1h,15m", description="Lista separada por vírgula"),
    limit: int | None = Query(default=None, ge=1, le=10000),
    _harness_id: Annotated[str | None, Depends(resolve_harness_id)] = None,
    provider: Annotated[MT5DataProvider, Depends(get_provider)] = None,
) -> dict[str, Any]:
    tfs = [t.strip() for t in timeframes.split(",") if t.strip()]
    if not tfs:
        raise HTTPException(status_code=422, detail="timeframes não pode ser vazio")
    return provider.fetch_multi_tf(symbol, tfs, limit=limit)


@app.post("/v1/ccxt/fetch_ohlcv")
async def ccxt_fetch_ohlcv(
    payload: dict[str, Any],
    _harness_id: Annotated[str | None, Depends(resolve_harness_id)] = None,
    provider: Annotated[MT5DataProvider, Depends(get_provider)] = None,
) -> dict[str, Any]:
    """RPC estilo CCXT — facilita adaptadores nos harnesses."""
    symbol = payload.get("symbol") or payload.get("pair")
    if not symbol:
        raise HTTPException(status_code=422, detail="symbol ou pair obrigatório")
    timeframe = payload.get("timeframe", "1h")
    limit = payload.get("limit")
    data = provider.fetch_ohlcv(str(symbol), timeframe=str(timeframe), limit=limit)
    return {"symbol": str(symbol).upper(), "timeframe": timeframe, "ohlcv": data}