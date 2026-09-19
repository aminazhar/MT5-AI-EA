#ifndef MT5_AI_CHART_DRAWER_MQH
#define MT5_AI_CHART_DRAWER_MQH

#include "CandleFinder.mqh"
#include "SignalReader.mqh"
#include "Constants.mqh"

bool ChartDrawer_SetFibonacciLevel(
   const string object_name,
   const int index,
   const double ratio,
   const string label,
   const double price
)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string level_text = label + " (" + DoubleToString(ratio * 100.0, 1) + "%) | " +
                       DoubleToString(price, digits);

   return(
      ObjectSetDouble(0, object_name, OBJPROP_LEVELVALUE, index, ratio) &&
      ObjectSetString(0, object_name, OBJPROP_LEVELTEXT, index, level_text) &&
      ObjectSetInteger(0, object_name, OBJPROP_LEVELCOLOR, index, clrBlack)
   );
}

bool ChartDrawer_DrawFibonacci(
   const string object_name,
   const Candle &candle,
   const SignalDirection direction
)
{
   if(object_name == "" || candle.time == 0 || candle.high <= candle.low)
      return(false);

   if(direction != SIGNAL_DIRECTION_BUY && direction != SIGNAL_DIRECTION_SELL)
      return(false);

   if(ObjectFind(0, object_name) >= 0)
      ObjectDelete(0, object_name);

   datetime second_anchor_time = candle.time + PeriodSeconds(PERIOD_M1);
   // BUY draws top-to-bottom; flipped SELL draws bottom-to-top.
   double first_anchor_price = direction == SIGNAL_DIRECTION_BUY ? candle.high : candle.low;
   double second_anchor_price = direction == SIGNAL_DIRECTION_BUY ? candle.low : candle.high;
   double range = candle.high - candle.low;
   double orientation = direction == SIGNAL_DIRECTION_BUY ? 1.0 : -1.0;

   if(!ObjectCreate(
      0,
      object_name,
      OBJ_FIBO,
      0,
      candle.time,
      first_anchor_price,
      second_anchor_time,
      second_anchor_price
   ))
      return(false);

   if(!ObjectSetInteger(0, object_name, OBJPROP_LEVELS, FIBONACCI_LEVEL_COUNT) ||
      !ObjectSetInteger(0, object_name, OBJPROP_RAY_RIGHT, true) ||
      !ObjectSetInteger(0, object_name, OBJPROP_COLOR, clrBlack) ||
      !ObjectSetInteger(0, object_name, OBJPROP_SELECTABLE, true) ||
      !ObjectSetInteger(0, object_name, OBJPROP_HIDDEN, false))
   {
      ObjectDelete(0, object_name);
      return(false);
   }

   if(!ChartDrawer_SetFibonacciLevel(object_name, 0, FIBONACCI_RATIO_VOID, "VOID", candle.high + (range * FIBONACCI_RATIO_VOID * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 1, FIBONACCI_RATIO_BO, "BO", candle.high + (range * FIBONACCI_RATIO_BO * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 2, FIBONACCI_RATIO_TP, "TP", candle.high + (range * FIBONACCI_RATIO_TP * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 3, FIBONACCI_RATIO_TP_E4_E7, "TP E4-E7", candle.high + (range * FIBONACCI_RATIO_TP_E4_E7 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 4, FIBONACCI_RATIO_E3, "E3", candle.high + (range * FIBONACCI_RATIO_E3 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 5, FIBONACCI_RATIO_E3_5, "E3.5", candle.high + (range * FIBONACCI_RATIO_E3_5 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 6, FIBONACCI_RATIO_E4, "E4", candle.high + (range * FIBONACCI_RATIO_E4 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 7, FIBONACCI_RATIO_E4_5, "E4.5", candle.high + (range * FIBONACCI_RATIO_E4_5 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 8, FIBONACCI_RATIO_E5, "E5", candle.high + (range * FIBONACCI_RATIO_E5 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 9, FIBONACCI_RATIO_E5_5, "E5.5", candle.high + (range * FIBONACCI_RATIO_E5_5 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 10, FIBONACCI_RATIO_E6, "E6", candle.high + (range * FIBONACCI_RATIO_E6 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 11, FIBONACCI_RATIO_E6_5, "E6.5", candle.high + (range * FIBONACCI_RATIO_E6_5 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 12, FIBONACCI_RATIO_E7, "E7", candle.high + (range * FIBONACCI_RATIO_E7 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 13, FIBONACCI_RATIO_E7_5, "E7.5", candle.high + (range * FIBONACCI_RATIO_E7_5 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 14, FIBONACCI_RATIO_E8, "E8", candle.high + (range * FIBONACCI_RATIO_E8 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 15, FIBONACCI_RATIO_E8_5, "E8.5", candle.high + (range * FIBONACCI_RATIO_E8_5 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 16, FIBONACCI_RATIO_E9, "E9", candle.high + (range * FIBONACCI_RATIO_E9 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 17, FIBONACCI_RATIO_E9_5, "E9.5", candle.high + (range * FIBONACCI_RATIO_E9_5 * orientation)) ||
      !ChartDrawer_SetFibonacciLevel(object_name, 18, FIBONACCI_RATIO_E10, "E10", candle.high + (range * FIBONACCI_RATIO_E10 * orientation)))
   {
      ObjectDelete(0, object_name);
      return(false);
   }

   ChartRedraw(0);
   return(true);
}

bool ChartDrawer_DrawFibonacci(
   const Candle &candle,
   const SignalDirection direction
)
{
   return(
      ChartDrawer_DrawFibonacci(
         FIBONACCI_OBJECT_NAME,
         candle,
         direction
      )
   );
}

bool ChartDrawer_RemoveFibonacci(const string object_name)
{
   if(object_name == "")
      return(false);

   if(ObjectFind(0, object_name) < 0)
      return(true);

   return(ObjectDelete(0, object_name));
}

#endif
