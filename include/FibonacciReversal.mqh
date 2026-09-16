#ifndef MT5_AI_FIBONACCI_REVERSAL_MQH
#define MT5_AI_FIBONACCI_REVERSAL_MQH

#include "SignalReader.mqh"
#include "CandleFinder.mqh"
#include "Fibonacci.mqh"
#include "ChartDrawer.mqh"
#include "BreakoutDetector.mqh"

struct FibonacciReversalResult
{
   bool            reversal_performed;
   bool            redraw_successful;
   FibonacciLevels levels;
};

void FibonacciReversal_Reset(FibonacciReversalResult &result)
{
   result.reversal_performed = false;
   result.redraw_successful = false;
   Fibonacci_Reset(result.levels);
}

bool FibonacciReversal_IsBreakoutValid(const BreakoutResult &breakout)
{
   if(breakout.type == BREAKOUT_NONE || breakout.type == BREAKOUT_BUY)
      return(!breakout.fibonacci_reversal_required);

   if(breakout.type == BREAKOUT_SELL)
      return(breakout.fibonacci_reversal_required);

   return(false);
}

bool FibonacciReversal_Apply(
   const Signal &signal,
   const Candle &candle,
   const BreakoutResult &breakout,
   FibonacciReversalResult &result
)
{
   FibonacciReversal_Reset(result);

   if(signal.symbol == "" || signal.timestamp <= 0 ||
      (signal.direction != SIGNAL_DIRECTION_BUY && signal.direction != SIGNAL_DIRECTION_SELL))
      return(false);

   if(candle.time != signal.timestamp || !MathIsValidNumber(candle.high) ||
      !MathIsValidNumber(candle.low) || candle.high <= candle.low)
      return(false);

   if(!FibonacciReversal_IsBreakoutValid(breakout))
      return(false);

   if(breakout.type != BREAKOUT_SELL || !breakout.fibonacci_reversal_required)
      return(true);

   if(!Fibonacci_Calculate(candle, SIGNAL_DIRECTION_SELL, result.levels))
      return(false);

   result.reversal_performed = true;

   if(!ChartDrawer_DrawFibonacci(candle, SIGNAL_DIRECTION_SELL))
      return(false);

   result.redraw_successful = true;
   return(true);
}

#endif
