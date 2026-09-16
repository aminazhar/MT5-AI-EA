#ifndef MT5_AI_SIGNAL_READER_MQH
#define MT5_AI_SIGNAL_READER_MQH

#include "Config.mqh"

enum SignalDirection
{
   SIGNAL_DIRECTION_UNKNOWN = 0,
   SIGNAL_DIRECTION_BUY,
   SIGNAL_DIRECTION_SELL
};

struct Signal
{
   string   symbol;
   datetime timestamp;
};

bool SignalReader_IsWhitespace(const ushort character)
{
   return(character == ' ' || character == '\t' || character == '\r' || character == '\n');
}

bool SignalReader_ExtractString(const string json, const string key, string &value)
{
   string key_pattern = "\"" + key + "\"";
   int key_start = StringFind(json, key_pattern);
   if(key_start < 0)
      return(false);

   int colon_position = StringFind(json, ":", key_start + StringLen(key_pattern));
   if(colon_position < 0)
      return(false);

   int value_start = colon_position + 1;
   int json_length = StringLen(json);

   while(value_start < json_length &&
         SignalReader_IsWhitespace((ushort)StringGetCharacter(json, value_start)))
      value_start++;

   if(value_start >= json_length || StringGetCharacter(json, value_start) != '"')
      return(false);

   value_start++;

   int value_end = value_start;
   while(value_end < json_length &&
         StringGetCharacter(json, value_end) != '"')
      value_end++;

   if(value_end >= json_length)
      return(false);

   value = StringSubstr(json, value_start, value_end - value_start);
   StringTrimLeft(value);
   StringTrimRight(value);

   return(value != "");
}

void SignalReader_Reset(Signal &signal)
{
   signal.symbol = "";
   signal.timestamp = 0;
}

bool SignalReader_Read(Signal &signal)
{
   SignalReader_Reset(signal);

   int file_handle = FileOpen(SIGNAL_FILE, FILE_READ | FILE_TXT | FILE_ANSI);
   if(file_handle == INVALID_HANDLE)
      return(false);

   string json = "";

   while(!FileIsEnding(file_handle))
      json += FileReadString(file_handle);

   FileClose(file_handle);

   string symbol;
   string timestamp_text;

   if(!SignalReader_ExtractString(json, "symbol", symbol) ||
      !SignalReader_ExtractString(json, "timestamp", timestamp_text))
      return(false);

   datetime timestamp = StringToTime(timestamp_text);

   if(symbol == "" || timestamp == 0)
      return(false);

   signal.symbol = symbol;
   signal.timestamp = timestamp;

   return(true);
}

#endif