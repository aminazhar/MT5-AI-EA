#ifndef MT5_AI_SHEET_LOG_WRITER_MQH
#define MT5_AI_SHEET_LOG_WRITER_MQH

#include "Config.mqh"
#include "SignalReader.mqh"
#include "CandleFinder.mqh"

string SheetLogWriter_MonthName(const int month)
{
   switch(month)
   {
      case 1:  return("Jan");
      case 2:  return("Feb");
      case 3:  return("Mar");
      case 4:  return("Apr");
      case 5:  return("May");
      case 6:  return("Jun");
      case 7:  return("Jul");
      case 8:  return("Aug");
      case 9:  return("Sep");
      case 10: return("Oct");
      case 11: return("Nov");
      case 12: return("Dec");
   }

   return("");
}

string SheetLogWriter_Decision(const long points)
{
   if(points < 35000)
      return("Trap");

   if(points <= 45000)
      return("Safe");

   return("Caution");
}

// Appends an idempotent signal-candle range record for the Python bridge.
// Price decimals are deliberately discarded before the difference is calculated.
bool SheetLogWriter_Append(
   const Signal &signal,
   const Candle &candle,
   const double range_points
)
{
   if(signal.symbol == "" || signal.timestamp == 0 ||
      candle.time == 0 || candle.high <= candle.low ||
      !MathIsValidNumber(range_points) || range_points < 0.0)
      return(false);

   long high_value = (long)MathFloor(candle.high);
   long low_value = (long)MathFloor(candle.low);
   long difference = high_value - low_value;
   long points_value = (long)MathRound(range_points);
   string decision = SheetLogWriter_Decision(points_value);
   string signal_type = SignalReader_IsNQ426(signal) ? "NQ426" : "Normal";
   string event_id = signal.symbol + "_" + IntegerToString((long)signal.timestamp) + "_" + signal_type;
   MqlDateTime signal_time;
   if(!TimeToStruct(signal.timestamp, signal_time))
      return(false);

   string sheet_date = StringFormat("%02d %s", signal_time.day, SheetLogWriter_MonthName(signal_time.mon));
   string sheet_time = StringFormat("%02d:%02d", signal_time.hour, signal_time.min);
   string payload = StringFormat(
      "{\"event_id\":\"%s\",\"date\":\"%s\",\"signal_type\":\"%s\",\"time\":\"%s\",\"symbol\":\"%s\",\"high\":%I64d,\"low\":%I64d,\"difference\":%I64d,\"points\":%I64d,\"decision\":\"%s\"}\r\n",
      event_id,
      sheet_date,
      signal_type,
      sheet_time,
      signal.symbol,
      high_value,
      low_value,
      difference,
      points_value,
      decision
   );

   int file_handle = FileOpen(
      SHEET_LOG_QUEUE_FILE,
      FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ
   );
   if(file_handle == INVALID_HANDLE)
      return(false);

   FileSeek(file_handle, 0, SEEK_END);
   uint written = FileWriteString(file_handle, payload);
   FileFlush(file_handle);
   FileClose(file_handle);

   return(written == StringLen(payload));
}

#endif
