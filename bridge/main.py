import asyncio
from datetime import datetime

from telethon import TelegramClient, events

from config import ConfigurationError, Settings, load_settings
from models import Signal
from parser import parse_signal
from writer import write_signal


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
        print("Message ignored: not NQ426 / invalid signal")
        print("----------------------------------------")
        return

    print("Valid NQ426 signal detected")
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
                    write_successful = write_signal(signal, settings.signal_output_path)
                    print_write_result(settings.signal_output_path, write_successful)

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


def main() -> None:
    try:
        settings = load_settings()
        asyncio.run(listen(settings))
    except ConfigurationError as error:
        print(f"Configuration error: {error}")
    except KeyboardInterrupt:
        print("\nTelegram listener stopped.")


if __name__ == "__main__":
    main()