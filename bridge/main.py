import asyncio
from datetime import datetime

from telethon import TelegramClient, events

from config import ConfigurationError, Settings, load_settings


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


async def listen(settings: Settings) -> None:
    while True:
        client = TelegramClient(SESSION_NAME, settings.api_id, settings.api_hash)

        try:
            await client.start(phone=settings.phone_number)
            channel = await resolve_channel(client, settings.channel_name)

            @client.on(events.NewMessage(chats=channel))
            async def handle_new_message(event):
                print_message(settings.channel_name, event.message.date, event.raw_text)

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
