import os
from dataclasses import dataclass

from dotenv import load_dotenv


class ConfigurationError(ValueError):
    """Raised when a required environment variable is missing or invalid."""


@dataclass(frozen=True)
class Settings:
    api_id: int
    api_hash: str
    phone_number: str
    channel_name: str
    signal_output_path: str


def _required_environment_variable(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise ConfigurationError(f"Missing required environment variable: {name}")
    return value


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
    )
