import re
from datetime import datetime
from typing import Final

from models import Signal


INDICATOR_PATTERN: Final[re.Pattern[str]] = re.compile(
    r"\bNQ426\b",
    re.IGNORECASE,
)

SYMBOL_MARKER: Final[str] = "\U0001F449"
SYMBOL_PATTERN: Final[re.Pattern[str]] = re.compile(
    r"^\s*" + SYMBOL_MARKER + r"\s*(?P<symbol>[^\r\n]+?)\s*$",
    re.MULTILINE,
)

TIMESTAMP_PATTERN: Final[re.Pattern[str]] = re.compile(
    r"C\.S\.T\s*:\s*(?P<timestamp>\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2})"
)

TIMESTAMP_FORMAT: Final[str] = "%Y.%m.%d %H:%M"
SUPPORTED_SYMBOL: Final[str] = "FixedVol100"


def parse_signal(message: str) -> Signal | None:
    if not isinstance(message, str):
        return None

    symbol_match = SYMBOL_PATTERN.search(message)
    timestamp_match = TIMESTAMP_PATTERN.search(message)

    if symbol_match is None or timestamp_match is None:
        return None

    # Telegram messages end the symbol line with sentence punctuation.
    # That punctuation is not part of the MT5 symbol name.
    symbol = symbol_match.group("symbol").strip().rstrip(".,;:!?")
    if symbol.casefold() != SUPPORTED_SYMBOL.casefold():
        return None

    try:
        timestamp = datetime.strptime(
            timestamp_match.group("timestamp"),
            TIMESTAMP_FORMAT,
        )
    except ValueError:
        return None

    return Signal(
        symbol=SUPPORTED_SYMBOL,
        timestamp=timestamp,
        signal_type="NQ426" if INDICATOR_PATTERN.search(message) else "Normal",
    )
