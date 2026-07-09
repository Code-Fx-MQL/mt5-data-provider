"""Autenticação API key para múltiplos harnesses."""

from __future__ import annotations

from fastapi import Header, HTTPException, status

from mt5_provider.config import get_settings
from mt5_provider.exceptions import UnauthorizedHarnessError


def resolve_harness_id(
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
    authorization: str | None = Header(default=None),
) -> str | None:
    """Retorna harness_id autenticado ou None se auth desativada."""
    settings = get_settings()
    key_map = settings.api_key_map
    if not key_map:
        return None

    token = x_api_key
    if not token and authorization:
        prefix = "bearer "
        if authorization.lower().startswith(prefix):
            token = authorization[len(prefix) :].strip()

    if not token or token not in key_map:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API key inválida ou ausente (header X-API-Key)",
        )
    return key_map[token]