#ifndef MT5_AI_CONFIG_MQH
#define MT5_AI_CONFIG_MQH

#define SIGNAL_FILE "signal.json"
#define SHEET_ONLY_SIGNAL_FILE "sheet_signal.json"
#define SHEET_LOG_QUEUE_FILE "fibo_sheet_queue.jsonl"

input double InpOrderVolume = 0.10;
input ulong InpMagicNumber = 42613;
input bool InpEnableFiboBreakoutStops = false;
input bool InpEnableAutoTrade = false;

#endif
