"""Per-request context helpers shared across API layers."""

from contextvars import ContextVar, Token

_trace_id_ctx: ContextVar[str | None] = ContextVar("trace_id", default=None)


def set_trace_id(trace_id: str) -> Token[str | None]:
    """Store trace_id for the active request context."""
    return _trace_id_ctx.set(trace_id)


def reset_trace_id(token: Token[str | None]) -> None:
    """Clear trace_id for the active request context."""
    _trace_id_ctx.reset(token)


def get_trace_id() -> str | None:
    """Return trace_id from current request context when available."""
    return _trace_id_ctx.get()