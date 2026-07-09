"""Exceções do MT5 Data Provider."""


class MT5ProviderError(Exception):
    """Erro base."""


class MT5ConnectionError(MT5ProviderError):
    """Falha ao conectar ao terminal MT5."""


class SymbolNotFoundError(MT5ProviderError):
    """Símbolo não encontrado no MT5."""


class InvalidTimeframeError(MT5ProviderError):
    """Timeframe não suportado."""


class UnauthorizedHarnessError(MT5ProviderError):
    """API key inválida ou ausente."""