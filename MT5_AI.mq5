#property copyright "MT5-AI-EA"
#property version   "1.0"
#property strict

#include "include/Config.mqh"
#include "include/Constants.mqh"
#include "include/SignalReader.mqh"
#include "include/CandleFinder.mqh"
#include "include/Fibonacci.mqh"
#include "include/ChartDrawer.mqh"
#include "include/Utils.mqh"

int OnInit()
{
   EventSetTimer(TIMER_INTERVAL_SECONDS);
   Print("[MT5-AI] EA Initialized");

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("[MT5-AI] EA Stopped");
}

void OnTimer()
{
   Signal signal;

   if(SignalReader_Read(signal))
   {
      string direction_text = signal.direction == SIGNAL_DIRECTION_BUY ? "BUY" : "SELL";

      PrintFormat(
         "[MT5-AI] Signal: Symbol=%s Direction=%s Time=%s",
         signal.symbol,
         direction_text,
         TimeToString(signal.timestamp, TIME_DATE | TIME_SECONDS)
      );

      Candle candle;
      if(CandleFinder_FindM1(signal.symbol, signal.timestamp, candle))
      {
         PrintFormat(
            "[MT5-AI] Candle: Time=%s Open=%G High=%G Low=%G Close=%G TickVolume=%I64d",
            TimeToString(candle.time, TIME_DATE | TIME_SECONDS),
            candle.open,
            candle.high,
            candle.low,
            candle.close,
            candle.tick_volume
         );
      }
      else
      {
         Print("[MT5-AI] M1 candle not found");
      }
   }
}
