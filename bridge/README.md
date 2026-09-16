# Bridge-1 Telegram Listener

This listener connects to one Telegram channel and prints each new message to the console. It does not parse messages, write JSON, or communicate with MetaTrader 5.

## Prerequisites

- Python 3.12 or later
- A Telegram account with access to the target channel
- Telegram API credentials

## Create Telegram API credentials

1. Sign in at [my.telegram.org](https://my.telegram.org).
2. Open **API development tools**.
3. Create an application.
4. Copy its `api_id` and `api_hash`.

## Install dependencies

From the `bridge` folder, create and activate a virtual environment if desired, then run:

```bash
pip install -r requirements.txt
```

## Create `.env`

Copy `.env.example` to `.env` and fill in the values:

```env
API_ID=123456
API_HASH=your_api_hash
PHONE_NUMBER=+1234567890
CHANNEL_NAME=Project V || SIGNAL
```

`CHANNEL_NAME` must exactly match the Telegram channel name shown in your dialogs.

## First login

On the first run, Telegram sends a verification code to your account. Enter the code when prompted. If two-step verification is enabled, enter the password when prompted. Telethon saves the authorized session locally so later runs do not normally require another login.

## Run

From the `bridge` folder:

```bash
python main.py
```

Press `Ctrl+C` to stop the listener gracefully.
