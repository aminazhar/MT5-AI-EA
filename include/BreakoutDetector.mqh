#ifndef MT5_AI_BREAKOUT_DETECTOR_MQH
#define MT5_AI_BREAKOUT_DETECTOR_MQH

#include "Fibonacci.mqh"

enum BreakoutType
{
   BREAKOUT_NONE,
   BREAKOUT_BUY,
   BREAKOUT_SELL
};

struct BreakoutResult
{
   BreakoutType type;
   double       bid;
   bool         fibonacci_reversal_required;
};

void BreakoutDetector_Reset(BreakoutResult &result)
{
   result.type = BREAKOUT_NONE;
   result.bid = 0.0;
   result.fibonacci_reversal_required = false;
}

bool BreakoutDetector_CheckBid(const string symbol, const FibonacciLevels &levels, BreakoutResult &result)
{
   BreakoutDetector_Reset(result);

   if(symbol == "" || !MathIsValidNumber(levels.bo) || !MathIsValidNumber(levels.e4))
      return(false);

   if(!SymbolInfoDouble(symbol, SYMBOL_BID, result.bid))
      return(false);

   if(result.bid >= levels.bo)
   {
      result.type = BREAKOUT_BUY;
   }
   else if(result.bid <= levels.e4)
   {
      result.type = BREAKOUT_SELL;
      result.fibonacci_reversal_required = true;
   }

   return(true);
}

#endif
