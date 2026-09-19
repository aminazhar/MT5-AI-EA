#ifndef MT5_AI_PENDING_ORDER_PLANNER_MQH
#define MT5_AI_PENDING_ORDER_PLANNER_MQH

#include "SignalReader.mqh"
#include "Fibonacci.mqh"
#include "RangeFilter.mqh"
#include "BreakoutDetector.mqh"
#include "Constants.mqh"

enum PendingOrderType
{
   PENDING_ORDER_BUY_STOP,
   PENDING_ORDER_BUY_LIMIT,
   PENDING_ORDER_SELL_STOP,
   PENDING_ORDER_SELL_LIMIT
};

struct PendingOrderEntry
{
   PendingOrderType type;
   double           price;
   double           take_profit;
};

struct PendingOrderPlan
{
   string            symbol;
   double            volume;
   ulong             magic_number;
   string            comment;
   PendingOrderEntry entries[MAX_PENDING_ORDERS];
   int               count;
};

void PendingOrderPlanner_Reset(PendingOrderPlan &plan)
{
   plan.symbol = "";
   plan.volume = 0.0;
   plan.magic_number = 0;
   plan.comment = "";
   plan.count = 0;
}

bool PendingOrderPlanner_Add(PendingOrderPlan &plan, const PendingOrderType type, const double price, const double take_profit)
{
   if(plan.count >= MAX_PENDING_ORDERS || !MathIsValidNumber(price) || !MathIsValidNumber(take_profit))
      return(false);

   plan.entries[plan.count].type = type;
   plan.entries[plan.count].price = price;
   plan.entries[plan.count].take_profit = take_profit;
   plan.count++;

   return(true);
}

bool PendingOrderPlanner_Create(
   const SignalDirection direction,
   const FibonacciLevels &levels,
   const RangeClassification classification,
   const BreakoutResult &breakout,
   PendingOrderPlan &plan
)
{
   PendingOrderPlanner_Reset(plan);

   if(direction != SIGNAL_DIRECTION_BUY && direction != SIGNAL_DIRECTION_SELL)
      return(false);

   if(classification != RANGE_CLASSIFICATION_REJECT &&
      classification != RANGE_CLASSIFICATION_NORMAL &&
      classification != RANGE_CLASSIFICATION_WIDE)
      return(false);

   if(breakout.type != BREAKOUT_NONE &&
      breakout.type != BREAKOUT_BUY &&
      breakout.type != BREAKOUT_SELL)
      return(false);

   if(classification == RANGE_CLASSIFICATION_REJECT || breakout.type == BREAKOUT_NONE)
      return(true);

   if(breakout.type == BREAKOUT_SELL && breakout.fibonacci_reversal_required)
      return(false);

   if((breakout.type == BREAKOUT_BUY && direction != SIGNAL_DIRECTION_BUY) ||
      (breakout.type == BREAKOUT_SELL && direction != SIGNAL_DIRECTION_SELL))
      return(false);

   if(classification == RANGE_CLASSIFICATION_NORMAL)
   {
      if(breakout.type == BREAKOUT_BUY)
      {
         return(
            PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.bo, levels.void_level) &&
            PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e3, levels.tp) &&
            PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e4, levels.tp_e4_e7) &&
            PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e5, levels.e3) &&
            PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e6, levels.e3) &&
            PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e7, levels.e3) &&
            PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e8, levels.e3) &&
            PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e9, levels.e3) &&
            PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e10, levels.e3)
         );
      }

      return(
         PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_STOP, levels.bo, levels.void_level) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e3, levels.tp) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e4, levels.tp_e4_e7) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e5, levels.e3) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e6, levels.e3) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e7, levels.e3) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e8, levels.e3) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e9, levels.e3) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e10, levels.e3)
      );
   }

   if(breakout.type == BREAKOUT_BUY)
   {
      return(
         PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e4, levels.tp_e4_e7) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e5, levels.e3) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e6, levels.e3) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e7, levels.e3) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e8, levels.e3) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e9, levels.e3) &&
         PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_LIMIT, levels.e10, levels.e3)
      );
   }

   return(
      PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e4, levels.tp_e4_e7) &&
      PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e5, levels.e3) &&
      PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e6, levels.e3) &&
      PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e7, levels.e3) &&
      PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e8, levels.e3) &&
      PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e9, levels.e3) &&
      PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_LIMIT, levels.e10, levels.e3)
   );
}

// Breakout-stop mode is intentionally limited to the two opposing stops.
// TP and SL remain empty so the trader can manage the filled position manually.
bool PendingOrderPlanner_CreateBreakoutStopPlan(
   const FibonacciLevels &levels,
   PendingOrderPlan &plan
)
{
   PendingOrderPlanner_Reset(plan);

   return(
      PendingOrderPlanner_Add(plan, PENDING_ORDER_BUY_STOP, levels.bo, 0.0) &&
      PendingOrderPlanner_Add(plan, PENDING_ORDER_SELL_STOP, levels.e4, 0.0)
   );
}

#endif
