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

string g_last_range_rejected_signal_key = "";

string SignalKey(const Signal &signal)
{
   return(signal.symbol + "_" + IntegerToString((long)signal.timestamp));
}

void NotifyRangeClassification(const RangeClassification classification, const double range_points)
{
   string message;

   if(classification == RANGE_CLASSIFICATION_REJECT)
      message = StringFormat("[MT5-AI] %.0f points: below 35k range - could be a trap. Fibonacci not drawn.", range_points);
   else if(classification == RANGE_CLASSIFICATION_NORMAL)
      message = StringFormat("[MT5-AI] %.0f points: within 35k-45k range - can proceed to trade.", range_points);
   else
      message = StringFormat("[MT5-AI] %.0f points: exceeds 45k normal range - proceed with caution.", range_points);

   Print(message);
   Alert(message);
}

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

   double range_points;
   RangeClassification classification;
   if(!RangeFilter_Classify(levels, signal.symbol, range_points, classification))
   {
      Print("[MT5-AI] Range classification failed");
      return(false);
   }

   PrintFormat("[MT5-AI] Range: Points=%.0f", range_points);

   string signal_key = SignalKey(signal);
   if(classification == RANGE_CLASSIFICATION_REJECT)
   {
      // signal.json remains unchanged after rejection, so alert only once per signal.
      if(g_last_range_rejected_signal_key != signal_key)
      {
         NotifyRangeClassification(classification, range_points);
         g_last_range_rejected_signal_key = signal_key;
      }

      return(true);
   }

   NotifyRangeClassification(classification, range_points);

   if(!SignalSetupManager_Add(signal, candle, levels, SIGNAL_DIRECTION_BUY, classification))
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
