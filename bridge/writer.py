import json
from pathlib import Path

from models import Signal


TIMESTAMP_FORMAT = "%Y.%m.%d %H:%M"
SHEET_ONLY_SIGNAL_FILENAME = "sheet_signal.json"


def _write_signal_file(signal: Signal, output_path: str) -> bool:
    try:
        path = Path(output_path)
        path.parent.mkdir(parents=True, exist_ok=True)

        payload = {
            "symbol": signal.symbol,
            "timestamp": signal.timestamp.strftime(TIMESTAMP_FORMAT),
            "signal_type": signal.signal_type,
        }
        path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=4) + "\n",
            encoding="utf-8",
        )
        return True
    except (AttributeError, OSError, TypeError, ValueError):
        return False


def write_signal(signal: Signal, output_path: str) -> bool:
    """Write an NQ426 signal consumed by the trading and drawing EA flow."""
    return _write_signal_file(signal, output_path)


def sheet_only_signal_path(signal_output_path: str) -> str:
    return str(Path(signal_output_path).with_name(SHEET_ONLY_SIGNAL_FILENAME))


def write_sheet_only_signal(signal: Signal, signal_output_path: str) -> bool:
    """Write a Normal signal for the EA's sheet logger only."""
    return _write_signal_file(signal, sheet_only_signal_path(signal_output_path))
