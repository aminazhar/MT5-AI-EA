import json
from pathlib import Path

from models import Signal


TIMESTAMP_FORMAT = "%Y.%m.%d %H:%M"


def write_signal(signal: Signal, output_path: str) -> bool:
    try:
        path = Path(output_path)
        path.parent.mkdir(parents=True, exist_ok=True)

        payload = {
            "symbol": signal.symbol,
            "timestamp": signal.timestamp.strftime(TIMESTAMP_FORMAT),
        }
        path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=4) + "\n",
            encoding="utf-8",
        )
        return True
    except (AttributeError, OSError, TypeError, ValueError):
        return False
