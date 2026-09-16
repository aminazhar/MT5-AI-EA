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
   Print("[MT5-AI] Timer Tick");

   Signal signal;

   if(SignalReader_Read(signal))
   {
      PrintFormat(
         "[MT5-AI] Signal: Symbol=%s Direction=%d Time=%s",
         signal.symbol,
         signal.direction,
         TimeToString(signal.timestamp, TIME_DATE | TIME_SECONDS)
      );
   }
}
