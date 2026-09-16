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

         FibonacciLevels levels;
         if(Fibonacci_Calculate(candle, signal.direction, levels))
         {
            PrintFormat(
               "[MT5-AI] Fibonacci: VOID=%G BO=%G TP=%G TP E4-E7=%G E3=%G E3.5=%G E4=%G",
               levels.void_level,
               levels.bo,
               levels.tp,
               levels.tp_e4_e7,
               levels.e3,
               levels.e3_5,
               levels.e4
            );

            PrintFormat(
               "[MT5-AI] Fibonacci: E4.5=%G E5=%G E5.5=%G E6=%G E6.5=%G E7=%G E7.5=%G",
               levels.e4_5,
               levels.e5,
               levels.e5_5,
               levels.e6,
               levels.e6_5,
               levels.e7,
               levels.e7_5
            );

            PrintFormat(
               "[MT5-AI] Fibonacci: E8=%G E8.5=%G E9=%G E9.5=%G E10=%G",
               levels.e8,
               levels.e8_5,
               levels.e9,
               levels.e9_5,
               levels.e10
            );
         }
         else
         {
            Print("[MT5-AI] Fibonacci calculation failed");
         }
      }
      else
      {
         Print("[MT5-AI] M1 candle not found");
      }
   }
}
