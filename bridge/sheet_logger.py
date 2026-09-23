import asyncio
import json
from pathlib import Path

from config import SheetLoggerSettings


POLL_INTERVAL_SECONDS = 10
QUOTA_RETRY_SECONDS = 60


def _offset_path(queue_path: Path) -> Path:
    return queue_path.with_suffix(queue_path.suffix + ".offset")


def _read_offset(queue_path: Path) -> int:
    try:
        return max(0, int(_offset_path(queue_path).read_text(encoding="utf-8").strip()))
    except (OSError, ValueError):
        return 0


def _write_offset(queue_path: Path, offset: int) -> None:
    _offset_path(queue_path).write_text(str(offset), encoding="utf-8")


def _record_row(record: dict[str, object]) -> tuple[str, list[object]]:
    required = ("event_id", "time", "high", "low")
    if any(key not in record for key in required):
        raise ValueError("Sheet-log queue record is missing a required field.")

    points = int(record["points"]) if "points" in record else 0
    decision = str(record.get("decision", _decision_for_points(points)))

    return str(record["event_id"]), [
        str(record.get("date", "")),
        str(record.get("signal_type", "NQ426")),
        str(record["time"]),
        int(record["high"]),
        int(record["low"]),
        points,
        decision,
    ]


def _decision_for_points(points: int) -> str:
    if points < 35_000:
        return "Trap"
    if points <= 45_000:
        return "Safe"
    return "Caution"


def _next_empty_sheet_row(rows: list[list[str]]) -> int:
    for row_number, row in enumerate(rows[1:], start=2):
        # Columns F and I contain formulas. A row is available when its input
        # cells (Date, Signal Type, Time, High, and Low) are all blank.
        if not any(cell.strip() for cell in row[:5]):
            return row_number

    return max(2, len(rows) + 1)


def upload_queued_rows(queue_path: Path, settings: SheetLoggerSettings) -> int:
    if not queue_path.exists():
        return 0

    offset = _read_offset(queue_path)
    queue_size = queue_path.stat().st_size
    if offset > queue_size:
        offset = 0
    if offset == queue_size:
        return 0

    pending_records: list[tuple[int, list[object]]] = []
    with queue_path.open("r", encoding="utf-8") as queue_file:
        queue_file.seek(offset)
        while line := queue_file.readline():
            pending_records.append((queue_file.tell(), _record_row(json.loads(line))[1]))

    if not pending_records:
        return 0

    import gspread
    from google.oauth2.service_account import Credentials

    scopes = ["https://www.googleapis.com/auth/spreadsheets"]
    credentials = Credentials.from_service_account_file(
        settings.service_account_file,
        scopes=scopes,
    )
    worksheet = gspread.authorize(credentials).open_by_key(
        settings.spreadsheet_id
    ).get_worksheet_by_id(settings.worksheet_id)
    if worksheet is None:
        raise RuntimeError(f"Google Sheet worksheet ID {settings.worksheet_id} was not found.")

    # One Google read per pending batch. Columns F and I are formulas owned
    # by the sheet; this logger only writes A:E and G:H.
    existing_rows = worksheet.get("A:H")
    existing_values = {
        tuple(existing_row[:5])
        for existing_row in existing_rows[1:]
        if len(existing_row) >= 5
    }
    next_row = _next_empty_sheet_row(existing_rows)
    updates: list[dict[str, object]] = []

    for _, row in pending_records:
        input_values = tuple(str(value) for value in row[:5])
        if input_values in existing_values:
            continue

        updates.extend(
            [
                {"range": f"A{next_row}:E{next_row}", "values": [row[:5]]},
                {"range": f"G{next_row}:H{next_row}", "values": [row[5:]]},
            ]
        )
        existing_values.add(input_values)
        next_row += 1

    if updates:
        worksheet.batch_update(updates, value_input_option="RAW")

    # Advance only after the complete batch was accepted by Google Sheets.
    _write_offset(queue_path, pending_records[-1][0])

    return len(updates) // 2


async def run_sheet_logger(signal_output_path: str, settings: SheetLoggerSettings) -> None:
    queue_path = Path(signal_output_path).with_name("fibo_sheet_queue.jsonl")
    print(f"Google Sheets logger enabled: {queue_path}")

    while True:
        try:
            uploaded_count = await asyncio.to_thread(
                upload_queued_rows,
                queue_path,
                settings,
            )
            if uploaded_count:
                print(f"Google Sheets rows appended: {uploaded_count}")
        except Exception as error:
            print(f"Google Sheets logger error: {error}")
            print(f"Google Sheets logger will retry in {QUOTA_RETRY_SECONDS} seconds.")
            await asyncio.sleep(QUOTA_RETRY_SECONDS)
            continue

        await asyncio.sleep(POLL_INTERVAL_SECONDS)
