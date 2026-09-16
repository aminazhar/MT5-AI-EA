#property copyright "MT5-AI-EA"
#property version   "1.0"
#property strict

#include "include/Config.mqh"
#include "include/Constants.mqh"
#include "include/SignalReader.mqh"
#include "include/CandleFinder.mqh"
#include "include/Fibonacci.mqh"
#include "include/SignalVerification.mqh"
#include "include/ChartDrawer.mqh"
#include "include/RangeFilter.mqh"
#include "include/MultiSignalFibonacciManager.mqh"
#include "include/Utils.mqh"

int OnInit()
{
   SignalSetupManager_Initialize();
   EventSetTimer(TIMER_INTERVAL_SECONDS);
   Print("[MT5-AI] EA-13 multi-signal Fibonacci manager initialized (visual-only)");

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("[MT5-AI] EA Stopped");
}

void PrintVerification(const VerificationResult &verification)
{
   PrintFormat("[MT5-AI] Signal Verification: %s", verification.signal_valid ? "PASS" : "FAIL");
   PrintFormat("[MT5-AI] Candle Verification: %s", verification.candle_valid ? "PASS" : "FAIL");
   PrintFormat("[MT5-AI] Fibonacci Verification: %s", verification.fibonacci_valid ? "PASS" : "FAIL");
   PrintFormat("[MT5-AI] Orientation Verification: %s", verification.orientation_valid ? "PASS" : "FAIL");
   PrintFormat("[MT5-AI] Overall Verification: %s", verification.verification_passed ? "PASS" : "FAIL");
}

void PrintFibonacci(const FibonacciLevels &levels)
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
}

bool PrepareNewSignal(const Signal &signal)
{
   if(SignalSetupManager_Find(signal.symbol, signal.timestamp) >= 0)
      return(true);

   PrintFormat(
      "[MT5-AI] Signal: Symbol=%s Time=%s",
      signal.symbol,
      TimeToString(signal.timestamp, TIME_DATE | TIME_SECONDS)
   );

   Candle candle;
   if(!CandleFinder_FindM1(signal.symbol, signal.timestamp, candle))
   {
      Print("[MT5-AI] M1 candle not found");
      return(false);
   }

   FibonacciLevels levels;
   if(!Fibonacci_Calculate(candle, SIGNAL_DIRECTION_BUY, levels))
   {
      Print("[MT5-AI] Fibonacci calculation failed");
      return(false);
   }

   VerificationResult verification;
   SignalVerification_Verify(signal, candle, levels, SIGNAL_DIRECTION_BUY, verification);
   PrintVerification(verification);
   PrintFibonacci(levels);

   double range;
   RangeClassification classification;
   if(RangeFilter_Classify(levels, range, classification))
      PrintFormat("[MT5-AI] Range: Value=%G", range);
   else
      Print("[MT5-AI] Range classification failed");

   if(!SignalSetupManager_Add(signal, candle, levels, SIGNAL_DIRECTION_BUY))
   {
      Print("[MT5-AI] Fibonacci drawing failed");
      return(false);
   }

   Print("[MT5-AI] Initial BUY Fibonacci drawn; execution remains disabled");
   return(true);
}

void OnTimer()
{
   Signal signal;

   if(SignalReader_Read(signal))
      PrepareNewSignal(signal);

   SignalSetupManager_MonitorAll();
}

void OnTick()
{
   // Catch level touches immediately on the chart symbol; the timer continues
   // to monitor setups on every tracked symbol.
   SignalSetupManager_MonitorAll();
}
