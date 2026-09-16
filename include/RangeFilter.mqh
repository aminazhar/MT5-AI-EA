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

bool RangeFilter_Classify(const FibonacciLevels &levels, double &range, RangeClassification &classification)
{
   range = 0.0;
   classification = RANGE_CLASSIFICATION_UNKNOWN;

   if(!MathIsValidNumber(levels.e3) || !MathIsValidNumber(levels.e5))
      return(false);

   range = MathAbs(levels.e3 - levels.e5);

   if(range < RANGE_REJECT_THRESHOLD)
      classification = RANGE_CLASSIFICATION_REJECT;
   else if(range <= RANGE_WIDE_THRESHOLD)
      classification = RANGE_CLASSIFICATION_NORMAL;
   else
      classification = RANGE_CLASSIFICATION_WIDE;

   return(true);
}

#endif
