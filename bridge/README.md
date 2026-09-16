# Bridge Telegram Listener, Parser, and Signal Writer

This bridge connects to one Telegram channel, prints each new message, parses supported signals, and writes valid signals to `signal.json`. It does not communicate with MetaTrader 5 directly.

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
SIGNAL_OUTPUT_PATH=C:\Users\<username>\AppData\Roaming\MetaQuotes\Terminal\<terminal-id>\MQL5\Files\signal.json
```

`CHANNEL_NAME` must exactly match the Telegram channel name shown in your dialogs.

`SIGNAL_OUTPUT_PATH` must be the complete path, including the `signal.json` filename, inside the MT5 terminal's `MQL5/Files` folder.

## Locate the MT5 `MQL5/Files` folder

1. Open MetaTrader 5.
2. Select **File** > **Open Data Folder**.
3. Open `MQL5`.
4. Open `Files`.
5. Copy the complete path and append `signal.json`.

Example:

```env
SIGNAL_OUTPUT_PATH=C:\Users\<username>\AppData\Roaming\MetaQuotes\Terminal\<terminal-id>\MQL5\Files\signal.json
```

## First login

On the first run, Telegram sends a verification code to your account. Enter the code when prompted. If two-step verification is enabled, enter the password when prompted. Telethon saves the authorized session locally so later runs do not normally require another login.

## Run

From the `bridge` folder:

```bash
python main.py
```

Press `Ctrl+C` to stop the listener gracefully.
