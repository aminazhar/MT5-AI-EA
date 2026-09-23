import asyncio
from datetime import datetime

from telethon import TelegramClient, events

from config import ConfigurationError, Settings, load_settings
from models import Signal
from parser import parse_signal
from sheet_logger import run_sheet_logger
from writer import sheet_only_signal_path, write_sheet_only_signal, write_signal


SESSION_NAME = "telegram_listener"
RECONNECT_DELAY_SECONDS = 5


async def resolve_channel(client: TelegramClient, channel_name: str):
    try:
        return await client.get_entity(channel_name)
    except (TypeError, ValueError):
        async for dialog in client.iter_dialogs():
            if dialog.name == channel_name:
                return dialog.entity

    raise RuntimeError(f"Telegram channel not found: {channel_name}")


def print_message(channel_name: str, message_time: datetime, message_text: str) -> None:
    local_time = message_time.astimezone().strftime("%Y-%m-%d %H:%M:%S")

    print("----------------------------------------")
    print("New Telegram Message")
    print("----------------------------------------")
    print(f"Channel : {channel_name}")
    print(f"Time    : {local_time}")
    print("Message :")
    print(message_text)
    print("----------------------------------------")


def print_signal(signal: Signal | None) -> None:
    print("Signal")
    print("----------------------------------------")

    if signal is None:
        print("Message ignored: invalid signal")
        print("----------------------------------------")
        return

    print("Valid signal detected")
    print(f"Type      : {signal.signal_type}")
    print(f"Symbol    : {signal.symbol}")
    print(f"Timestamp : {signal.timestamp:%Y-%m-%d %H:%M:%S}")
    print("----------------------------------------")


def print_write_result(output_path: str, write_successful: bool) -> None:
    if write_successful:
        print("Signal write success")
        print(f"Path : {output_path}")
        print("----------------------------------------")
        return

    print("Signal write failed")
    print("----------------------------------------")


async def listen(settings: Settings) -> None:
    while True:
        client = TelegramClient(SESSION_NAME, settings.api_id, settings.api_hash)

        try:
            await client.start(phone=settings.phone_number)
            channel = await resolve_channel(client, settings.channel_name)

            @client.on(events.NewMessage(chats=channel))
            async def handle_new_message(event):
                print_message(settings.channel_name, event.message.date, event.raw_text)

                signal = parse_signal(event.raw_text)
                print_signal(signal)

                if signal is not None:
                    if signal.signal_type == "NQ426":
                        output_path = settings.signal_output_path
                        write_successful = write_signal(signal, output_path)
                    else:
                        output_path = sheet_only_signal_path(settings.signal_output_path)
                        write_successful = write_sheet_only_signal(signal, settings.signal_output_path)

                    print_write_result(output_path, write_successful)

                print()

            print(f"Listening for new messages in: {settings.channel_name}")
            await client.run_until_disconnected()
            print("Telegram disconnected. Reconnecting...")

        except asyncio.CancelledError:
            raise
        except Exception as error:
            print(f"Telegram listener error: {error}")
            print(f"Reconnecting in {RECONNECT_DELAY_SECONDS} seconds...")
        finally:
            if client.is_connected():
                await client.disconnect()

        await asyncio.sleep(RECONNECT_DELAY_SECONDS)


async def run(settings: Settings) -> None:
    sheet_logger_task: asyncio.Task[None] | None = None
    if settings.sheet_logger is not None:
        sheet_logger_task = asyncio.create_task(
            run_sheet_logger(settings.signal_output_path, settings.sheet_logger)
        )
    else:
        print("Google Sheets logger disabled: Google Sheets settings are not configured.")

    try:
        await listen(settings)
    finally:
        if sheet_logger_task is not None:
            sheet_logger_task.cancel()
            await asyncio.gather(sheet_logger_task, return_exceptions=True)


def main() -> None:
    try:
        settings = load_settings()
        asyncio.run(run(settings))
    except ConfigurationError as error:
        print(f"Configuration error: {error}")
    except KeyboardInterrupt:
        print("\nTelegram listener stopped.")


if __name__ == "__main__":
    main()
