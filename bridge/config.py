import os
from dataclasses import dataclass

from dotenv import load_dotenv


class ConfigurationError(ValueError):
    """Raised when a required environment variable is missing or invalid."""


@dataclass(frozen=True)
class SheetLoggerSettings:
    service_account_file: str
    spreadsheet_id: str
    worksheet_id: int


@dataclass(frozen=True)
class Settings:
    api_id: int
    api_hash: str
    phone_number: str
    channel_name: str
    signal_output_path: str
    sheet_logger: SheetLoggerSettings | None


def _required_environment_variable(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise ConfigurationError(f"Missing required environment variable: {name}")
    return value


def _optional_sheet_logger_settings() -> SheetLoggerSettings | None:
    service_account_file = os.getenv("GOOGLE_SERVICE_ACCOUNT_FILE", "").strip()
    spreadsheet_id = os.getenv("GOOGLE_SHEET_ID", "").strip()
    worksheet_id_text = os.getenv("GOOGLE_SHEET_WORKSHEET_ID", "").strip()

    values = (service_account_file, spreadsheet_id, worksheet_id_text)
    if not any(values):
        return None

    if not all(values):
        raise ConfigurationError(
            "GOOGLE_SERVICE_ACCOUNT_FILE, GOOGLE_SHEET_ID, and "
            "GOOGLE_SHEET_WORKSHEET_ID must be set together."
        )

    try:
        worksheet_id = int(worksheet_id_text)
    except ValueError as error:
        raise ConfigurationError("GOOGLE_SHEET_WORKSHEET_ID must be an integer.") from error

    return SheetLoggerSettings(
        service_account_file=service_account_file,
        spreadsheet_id=spreadsheet_id,
        worksheet_id=worksheet_id,
    )


def load_settings() -> Settings:
    load_dotenv()

    api_id_text = _required_environment_variable("API_ID")
    try:
        api_id = int(api_id_text)
    except ValueError as error:
        raise ConfigurationError("API_ID must be an integer.") from error

    return Settings(
        api_id=api_id,
        api_hash=_required_environment_variable("API_HASH"),
        phone_number=_required_environment_variable("PHONE_NUMBER"),
        channel_name=_required_environment_variable("CHANNEL_NAME"),
        signal_output_path=_required_environment_variable("SIGNAL_OUTPUT_PATH"),
        sheet_logger=_optional_sheet_logger_settings(),
    )
