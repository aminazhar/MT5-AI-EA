#ifndef MT5_AI_FIBONACCI_MQH
#define MT5_AI_FIBONACCI_MQH

#include "CandleFinder.mqh"
#include "SignalReader.mqh"
#include "Constants.mqh"

struct FibonacciLevels
{
   double void_level;
   double bo;
   double tp;
   double tp_e4_e7;
   double e3;
   double e3_5;
   double e4;
   double e4_5;
   double e5;
   double e5_5;
   double e6;
   double e6_5;
   double e7;
   double e7_5;
   double e8;
   double e8_5;
   double e9;
   double e9_5;
   double e10;
};

void Fibonacci_Reset(FibonacciLevels &levels)
{
   levels.void_level = 0.0;
   levels.bo         = 0.0;
   levels.tp         = 0.0;
   levels.tp_e4_e7   = 0.0;
   levels.e3         = 0.0;
   levels.e3_5       = 0.0;
   levels.e4         = 0.0;
   levels.e4_5       = 0.0;
   levels.e5         = 0.0;
   levels.e5_5       = 0.0;
   levels.e6         = 0.0;
   levels.e6_5       = 0.0;
   levels.e7         = 0.0;
   levels.e7_5       = 0.0;
   levels.e8         = 0.0;
   levels.e8_5       = 0.0;
   levels.e9         = 0.0;
   levels.e9_5       = 0.0;
   levels.e10        = 0.0;
}

bool Fibonacci_Calculate(const Candle &candle, const SignalDirection direction, FibonacciLevels &levels)
{
   Fibonacci_Reset(levels);

   if(candle.time == 0 || candle.high <= candle.low)
      return(false);

   if(direction != SIGNAL_DIRECTION_BUY && direction != SIGNAL_DIRECTION_SELL)
      return(false);

   const double range = candle.high - candle.low;
   // The flipped SELL chart draws bottom-to-top. MT5 maps its visible zero
   // level to the candle high, so order levels must use that same anchor.
   const double anchor = candle.high;
   const double orientation = direction == SIGNAL_DIRECTION_BUY ? 1.0 : -1.0;

   levels.void_level = anchor + (range * FIBONACCI_RATIO_VOID * orientation);
   levels.bo         = anchor + (range * FIBONACCI_RATIO_BO * orientation);
   levels.tp         = anchor + (range * FIBONACCI_RATIO_TP * orientation);
   levels.tp_e4_e7   = anchor + (range * FIBONACCI_RATIO_TP_E4_E7 * orientation);
   levels.e3         = anchor + (range * FIBONACCI_RATIO_E3 * orientation);
   levels.e3_5       = anchor + (range * FIBONACCI_RATIO_E3_5 * orientation);
   levels.e4         = anchor + (range * FIBONACCI_RATIO_E4 * orientation);
   levels.e4_5       = anchor + (range * FIBONACCI_RATIO_E4_5 * orientation);
   levels.e5         = anchor + (range * FIBONACCI_RATIO_E5 * orientation);
   levels.e5_5       = anchor + (range * FIBONACCI_RATIO_E5_5 * orientation);
   levels.e6         = anchor + (range * FIBONACCI_RATIO_E6 * orientation);
   levels.e6_5       = anchor + (range * FIBONACCI_RATIO_E6_5 * orientation);
   levels.e7         = anchor + (range * FIBONACCI_RATIO_E7 * orientation);
   levels.e7_5       = anchor + (range * FIBONACCI_RATIO_E7_5 * orientation);
   levels.e8         = anchor + (range * FIBONACCI_RATIO_E8 * orientation);
   levels.e8_5       = anchor + (range * FIBONACCI_RATIO_E8_5 * orientation);
   levels.e9         = anchor + (range * FIBONACCI_RATIO_E9 * orientation);
   levels.e9_5       = anchor + (range * FIBONACCI_RATIO_E9_5 * orientation);
   levels.e10        = anchor + (range * FIBONACCI_RATIO_E10 * orientation);

   return(true);
}

#endif
