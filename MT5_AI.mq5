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
   if(InpEnableFiboBreakoutStops && InpEnableAutoTrade)
   {
      string message = "[MT5-AI] Enable either Fibo Breakout Stops or EA Auto Trade, not both.";
      Print(message);
      Alert(message);
      return(INIT_PARAMETERS_INCORRECT);
   }

   SignalSetupManager_Initialize();
   EventSetTimer(TIMER_INTERVAL_SECONDS);
   if(InpEnableFiboBreakoutStops)
      Print("[MT5-AI] Fibonacci breakout-stop mode initialized (manual TP/SL)");
   else if(InpEnableAutoTrade)
      Print("[MT5-AI] EA auto-trade mode initialized");
   else
      Print("[MT5-AI] Visual-only Fibonacci mode initialized");

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

   datetime recovered_breakout_time = 0;
   HistoricalRecoveryState recovery = HISTORICAL_RECOVERY_NONE;
   if(InpEnableAutoTrade)
   {
      recovery = SignalSetupManager_ScanBuyHistory(signal.symbol, signal.timestamp, levels, recovered_breakout_time);
      if(recovery == HISTORICAL_RECOVERY_COMPLETED)
      {
         Print("[MT5-AI] Historical recovery: BO->VOID already completed; Fibonacci not redrawn");
         return(true);
      }
   }

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

   if(InpEnableAutoTrade && recovery == HISTORICAL_RECOVERY_BO_ACTIVE)
   {
      int setup_index = SignalSetupManager_Find(signal.symbol, signal.timestamp);
      if(setup_index >= 0)
      {
         g_signal_setups[setup_index].breakout_detected = true;
         g_signal_setups[setup_index].breakout_type = SETUP_BREAKOUT_BO;
         g_signal_setups[setup_index].breakout_candle_time = recovered_breakout_time;
         g_signal_setups[setup_index].recovered_from_history = true;
         SignalSetupManager_MarkRecoveryTouchedLevels(g_signal_setups[setup_index], g_signal_setups[setup_index].breakout_candle_time);
         // Historical recovery has already evaluated all closed candles up to
         // this point. Continue with the next newly closed candle only.
         g_signal_setups[setup_index].last_evaluated_candle_time = iTime(signal.symbol, PERIOD_M1, 1);
         SignalSetupManager_PlaceEntryOrders(g_signal_setups[setup_index]);
         Print("[MT5-AI] Historical recovery: BO breakout restored; pullback orders placed");
      }
   }

   if(InpEnableFiboBreakoutStops)
      Print("[MT5-AI] Initial BUY Fibonacci drawn; BO/E4 stop pair will arm after the signal candle");
   else if(InpEnableAutoTrade)
      Print("[MT5-AI] Initial BUY Fibonacci drawn; waiting for close-confirmed BO or E4 route");
   else
      Print("[MT5-AI] Initial BUY Fibonacci drawn; trading is disabled");
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

void OnTradeTransaction(const MqlTradeTransaction &transaction, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   SignalSetupManager_OnTradeTransaction(transaction);
}
