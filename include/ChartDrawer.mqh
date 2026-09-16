#ifndef MT5_AI_CHART_DRAWER_MQH
#define MT5_AI_CHART_DRAWER_MQH

#include "CandleFinder.mqh"
#include "SignalReader.mqh"
#include "Constants.mqh"

bool ChartDrawer_SetFibonacciLevel(const int index, const double ratio, const string label)
{
   return(
      ObjectSetDouble(0, FIBONACCI_OBJECT_NAME, OBJPROP_LEVELVALUE, index, ratio) &&
      ObjectSetString(0, FIBONACCI_OBJECT_NAME, OBJPROP_LEVELTEXT, index, label)
   );
}

bool ChartDrawer_DrawFibonacci(const Candle &candle, const SignalDirection direction)
{
   if(candle.time == 0 || candle.high <= candle.low)
      return(false);

   if(direction != SIGNAL_DIRECTION_BUY && direction != SIGNAL_DIRECTION_SELL)
      return(false);

   if(ObjectFind(0, FIBONACCI_OBJECT_NAME) >= 0 && !ObjectDelete(0, FIBONACCI_OBJECT_NAME))
      return(false);

   const datetime second_anchor_time = candle.time + PeriodSeconds(PERIOD_M1);
   const double first_anchor_price = direction == SIGNAL_DIRECTION_BUY ? candle.high : candle.low;
   const double second_anchor_price = direction == SIGNAL_DIRECTION_BUY ? candle.low : candle.high;

   if(!ObjectCreate(
      0,
      FIBONACCI_OBJECT_NAME,
      OBJ_FIBO,
      0,
      candle.time,
      first_anchor_price,
      second_anchor_time,
      second_anchor_price
   ))
      return(false);

   if(!ObjectSetInteger(0, FIBONACCI_OBJECT_NAME, OBJPROP_LEVELS, FIBONACCI_LEVEL_COUNT) ||
      !ObjectSetInteger(0, FIBONACCI_OBJECT_NAME, OBJPROP_RAY_RIGHT, true))
   {
      ObjectDelete(0, FIBONACCI_OBJECT_NAME);
      return(false);
   }

   if(!ChartDrawer_SetFibonacciLevel(0, FIBONACCI_RATIO_VOID, "VOID") ||
      !ChartDrawer_SetFibonacciLevel(1, FIBONACCI_RATIO_BO, "BO") ||
      !ChartDrawer_SetFibonacciLevel(2, FIBONACCI_RATIO_TP, "TP") ||
      !ChartDrawer_SetFibonacciLevel(3, FIBONACCI_RATIO_TP_E4_E7, "TP E4-E7") ||
      !ChartDrawer_SetFibonacciLevel(4, FIBONACCI_RATIO_E3, "E3") ||
      !ChartDrawer_SetFibonacciLevel(5, FIBONACCI_RATIO_E3_5, "E3.5") ||
      !ChartDrawer_SetFibonacciLevel(6, FIBONACCI_RATIO_E4, "E4") ||
      !ChartDrawer_SetFibonacciLevel(7, FIBONACCI_RATIO_E4_5, "E4.5") ||
      !ChartDrawer_SetFibonacciLevel(8, FIBONACCI_RATIO_E5, "E5") ||
      !ChartDrawer_SetFibonacciLevel(9, FIBONACCI_RATIO_E5_5, "E5.5") ||
      !ChartDrawer_SetFibonacciLevel(10, FIBONACCI_RATIO_E6, "E6") ||
      !ChartDrawer_SetFibonacciLevel(11, FIBONACCI_RATIO_E6_5, "E6.5") ||
      !ChartDrawer_SetFibonacciLevel(12, FIBONACCI_RATIO_E7, "E7") ||
      !ChartDrawer_SetFibonacciLevel(13, FIBONACCI_RATIO_E7_5, "E7.5") ||
      !ChartDrawer_SetFibonacciLevel(14, FIBONACCI_RATIO_E8, "E8") ||
      !ChartDrawer_SetFibonacciLevel(15, FIBONACCI_RATIO_E8_5, "E8.5") ||
      !ChartDrawer_SetFibonacciLevel(16, FIBONACCI_RATIO_E9, "E9") ||
      !ChartDrawer_SetFibonacciLevel(17, FIBONACCI_RATIO_E9_5, "E9.5") ||
      !ChartDrawer_SetFibonacciLevel(18, FIBONACCI_RATIO_E10, "E10"))
   {
      ObjectDelete(0, FIBONACCI_OBJECT_NAME);
      return(false);
   }

   ChartRedraw(0);
   return(true);
}

#endif
