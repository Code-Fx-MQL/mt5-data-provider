"""CLI para iniciar o servidor."""

from __future__ import annotations

import uvicorn

from mt5_provider.config import get_settings


def main() -> None:
    settings = get_settings()
    uvicorn.run(
        "mt5_provider.app:app",
        host=settings.mt5_host,
        port=settings.mt5_port,
        reload=False,
    )


if __name__ == "__main__":
    main()