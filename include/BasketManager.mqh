#ifndef MT5_AI_BASKET_MANAGER_MQH
#define MT5_AI_BASKET_MANAGER_MQH

#include "Fibonacci.mqh"
#include "PendingOrderPlanner.mqh"
#include "TradeExecutor.mqh"

enum BasketDirection
{
   BASKET_DIRECTION_NONE,
   BASKET_DIRECTION_BUY,
   BASKET_DIRECTION_SELL
};

struct BasketConfiguration
{
   BasketDirection direction;
   ulong           tickets[6];
   int             placed_order_count;
   double          take_profit;
   double          take_profit_e4_e7;
};

void BasketManager_Reset(BasketConfiguration &basket)
{
   basket.direction = BASKET_DIRECTION_NONE;
   basket.placed_order_count = 0;
   basket.take_profit = 0.0;
   basket.take_profit_e4_e7 = 0.0;
}

bool BasketManager_GetDirection(const PendingOrderType order_type, BasketDirection &direction)
{
   if(order_type == PENDING_ORDER_BUY_STOP || order_type == PENDING_ORDER_BUY_LIMIT)
      direction = BASKET_DIRECTION_BUY;
   else if(order_type == PENDING_ORDER_SELL_STOP || order_type == PENDING_ORDER_SELL_LIMIT)
      direction = BASKET_DIRECTION_SELL;
   else
      return(false);

   return(true);
}

bool BasketManager_Create(
   const FibonacciLevels &levels,
   const PendingOrderPlan &plan,
   const TradeExecutionResult &execution,
   BasketConfiguration &basket
)
{
   BasketManager_Reset(basket);

   if(plan.count < 0 ||
      plan.count > 6 ||
      execution.count < 0 ||
      execution.count > 6 ||
      plan.count != execution.count ||
      !MathIsValidNumber(levels.tp) ||
      !MathIsValidNumber(levels.tp_e4_e7))
      return(false);

   basket.take_profit = levels.tp;
   basket.take_profit_e4_e7 = levels.tp_e4_e7;

   for(int index = 0; index < execution.count; index++)
   {
      if(execution.results[index].status != EXECUTION_STATUS_PLACED)
         continue;

      if(execution.results[index].ticket == 0)
         return(false);

      BasketDirection order_direction;
      if(!BasketManager_GetDirection(execution.results[index].type, order_direction))
         return(false);

      if(basket.direction == BASKET_DIRECTION_NONE)
         basket.direction = order_direction;
      else if(basket.direction != order_direction)
         return(false);

      basket.tickets[basket.placed_order_count] = execution.results[index].ticket;
      basket.placed_order_count++;
   }

   return(true);
}

#endif
