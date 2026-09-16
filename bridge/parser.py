import re
from datetime import datetime
from typing import Final

from models import Signal


SYMBOL_MARKER: Final[str] = "\U0001F449"
SYMBOL_PATTERN: Final[re.Pattern[str]] = re.compile(
    r"^\s*" + SYMBOL_MARKER + r"\s*(?P<symbol>[^\r\n]+?)\s*$",
    re.MULTILINE,
)
TIMESTAMP_PATTERN: Final[re.Pattern[str]] = re.compile(
    r"C\.S\.T\s*:\s*(?P<timestamp>\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2})"
)
TIMESTAMP_FORMAT: Final[str] = "%Y.%m.%d %H:%M"


def parse_signal(message: str) -> Signal | None:
    if not isinstance(message, str):
        return None

    symbol_match = SYMBOL_PATTERN.search(message)
    timestamp_match = TIMESTAMP_PATTERN.search(message)
    if symbol_match is None or timestamp_match is None:
        return None

    symbol = symbol_match.group("symbol").strip()
    if not symbol:
        return None

    try:
        timestamp = datetime.strptime(
            timestamp_match.group("timestamp"), TIMESTAMP_FORMAT
        )
    except ValueError:
        return None

    return Signal(symbol=symbol, timestamp=timestamp)
