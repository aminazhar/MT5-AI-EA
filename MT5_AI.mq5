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
#include "include/BreakoutDetector.mqh"
#include "include/FibonacciReversal.mqh"
#include "include/Utils.mqh"

string          g_active_symbol = "";
datetime        g_active_timestamp = 0;
SignalDirection g_active_direction = SIGNAL_DIRECTION_UNKNOWN;
Candle          g_active_candle;
FibonacciLevels g_active_levels;

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

bool IsNewSignal(const Signal &signal)
{
   return(signal.symbol != g_active_symbol || signal.timestamp != g_active_timestamp);
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

bool PrepareNewSignal(const Signal &signal)
{
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
   if(!Fibonacci_Calculate(candle, SIGNAL_DIRECTION_BUY, levels))
   {
      Print("[MT5-AI] Fibonacci calculation failed");
      return(false);
   }

   if(!ChartDrawer_DrawFibonacci(candle, SIGNAL_DIRECTION_BUY))
   {
      Print("[MT5-AI] Fibonacci drawing failed");
      return(false);
   }

   VerificationResult verification;
   SignalVerification_Verify(signal, candle, levels, SIGNAL_DIRECTION_BUY, verification);
   PrintVerification(verification);
   PrintFibonacci(levels);

   double range;
   RangeClassification classification;
   if(RangeFilter_Classify(levels, range, classification))
   {
      string classification_name = classification == RANGE_CLASSIFICATION_REJECT ? "REJECT" :
                                   classification == RANGE_CLASSIFICATION_NORMAL ? "NORMAL" : "WIDE";

      PrintFormat(
         "[MT5-AI] Range: Value=%G Classification=%s",
         range,
         classification_name
      );
   }
   else
   {
      Print("[MT5-AI] Range classification failed");
   }

   g_active_symbol = signal.symbol;
   g_active_timestamp = signal.timestamp;
   g_active_direction = SIGNAL_DIRECTION_BUY;
   g_active_candle = candle;
   g_active_levels = levels;

   Print("[MT5-AI] Initial BUY Fibonacci drawn");

   return(true);
}

void MonitorBreakout(const Signal &signal)
{
   if(g_active_symbol == "" || g_active_timestamp == 0)
      return;

   BreakoutResult breakout;
   if(!BreakoutDetector_CheckBid(g_active_symbol, g_active_levels, breakout))
   {
      Print("[MT5-AI] Breakout detection failed");
      return;
   }

   if(breakout.type == BREAKOUT_NONE)
      return;

   string breakout_type = breakout.type == BREAKOUT_BUY ? "BUY" :
                          breakout.type == BREAKOUT_SELL ? "SELL" : "NONE";

   PrintFormat(
      "[MT5-AI] Breakout: Bid=%G Type=%s FibonacciReversalRequired=%s",
      breakout.bid,
      breakout_type,
      breakout.fibonacci_reversal_required ? "YES" : "NO"
   );

   if(breakout.type == BREAKOUT_BUY)
      return;

   if(g_active_direction == SIGNAL_DIRECTION_SELL)
      return;

   FibonacciReversalResult reversal;
   bool reversal_successful = FibonacciReversal_Apply(signal, g_active_candle, breakout, reversal);

   PrintFormat("[MT5-AI] Reversal Triggered: %s", reversal.reversal_performed ? "YES" : "NO");
   PrintFormat("[MT5-AI] Fibonacci Recalculated: %s", reversal.reversal_performed ? "YES" : "NO");
   PrintFormat("[MT5-AI] Chart Redrawn: %s", reversal.redraw_successful ? "YES" : "NO");
   PrintFormat("[MT5-AI] Fibonacci Reversal Overall: %s", reversal_successful ? "PASS" : "FAIL");

   if(reversal_successful && reversal.reversal_performed)
   {
      g_active_levels = reversal.levels;
      g_active_direction = SIGNAL_DIRECTION_SELL;

      VerificationResult verification;
      SignalVerification_Verify(signal, g_active_candle, g_active_levels, SIGNAL_DIRECTION_SELL, verification);
      PrintVerification(verification);
      PrintFibonacci(g_active_levels);

      Print("[MT5-AI] SELL Fibonacci drawn");
   }
}

void OnTimer()
{
   Signal signal;

   if(!SignalReader_Read(signal))
      return;

   if(IsNewSignal(signal))
   {
      if(!PrepareNewSignal(signal))
         return;
   }

   MonitorBreakout(signal);
}