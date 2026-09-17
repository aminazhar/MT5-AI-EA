#ifndef MT5_AI_RANGE_FILTER_MQH
#define MT5_AI_RANGE_FILTER_MQH

#include "Fibonacci.mqh"
#include "Constants.mqh"

enum RangeClassification
{
   RANGE_CLASSIFICATION_UNKNOWN = 0,
   RANGE_CLASSIFICATION_REJECT,
   RANGE_CLASSIFICATION_NORMAL,
   RANGE_CLASSIFICATION_WIDE
};

// Returns the E3-to-E5 distance in symbol points, not raw price units.
bool RangeFilter_Classify(
   const FibonacciLevels &levels,
   const string symbol,
   double &range_points,
   RangeClassification &classification
)
{
   range_points = 0.0;
   classification = RANGE_CLASSIFICATION_UNKNOWN;

   double point_size = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(!MathIsValidNumber(levels.e3) || !MathIsValidNumber(levels.e5) || point_size <= 0.0)
      return(false);

   range_points = MathAbs(levels.e3 - levels.e5) / point_size;

   if(range_points < RANGE_REJECT_THRESHOLD)
      classification = RANGE_CLASSIFICATION_REJECT;
   else if(range_points <= RANGE_WIDE_THRESHOLD)
      classification = RANGE_CLASSIFICATION_NORMAL;
   else
      classification = RANGE_CLASSIFICATION_WIDE;

   return(true);
}

#endif
