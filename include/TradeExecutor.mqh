#ifndef MT5_AI_TRADE_EXECUTOR_MQH
#define MT5_AI_TRADE_EXECUTOR_MQH

#include "PendingOrderPlanner.mqh"

enum ExecutionStatus
{
   EXECUTION_STATUS_NOT_ATTEMPTED,
   EXECUTION_STATUS_PLACED,
   EXECUTION_STATUS_FAILED
};

struct OrderExecutionResult
{
   PendingOrderType type;
   double           price;
   ExecutionStatus  status;
   uint             retcode;
   ulong            ticket;
};

struct TradeExecutionResult
{
   OrderExecutionResult results[MAX_PENDING_ORDERS];
   int                  count;
};

void TradeExecutor_Reset(TradeExecutionResult &result)
{
   result.count = 0;
}

bool TradeExecutor_MapOrderType(const PendingOrderType pending_order_type, ENUM_ORDER_TYPE &order_type)
{
   if(pending_order_type == PENDING_ORDER_BUY_STOP)
      order_type = ORDER_TYPE_BUY_STOP;
   else if(pending_order_type == PENDING_ORDER_BUY_LIMIT)
      order_type = ORDER_TYPE_BUY_LIMIT;
   else if(pending_order_type == PENDING_ORDER_SELL_STOP)
      order_type = ORDER_TYPE_SELL_STOP;
   else if(pending_order_type == PENDING_ORDER_SELL_LIMIT)
      order_type = ORDER_TYPE_SELL_LIMIT;
   else
      return(false);

   return(true);
}

bool TradeExecutor_IsPlanValid(const PendingOrderPlan &plan)
{
   if(plan.count < 0 ||
      plan.count > MAX_PENDING_ORDERS)
      return(false);

   if(plan.count == 0)
      return(true);

   if(plan.symbol == "" ||
      !MathIsValidNumber(plan.volume) ||
      plan.volume <= 0.0)
      return(false);

   for(int index = 0; index < plan.count; index++)
   {
      ENUM_ORDER_TYPE order_type;
      if(!MathIsValidNumber(plan.entries[index].price) ||
         !MathIsValidNumber(plan.entries[index].take_profit) ||
         !TradeExecutor_MapOrderType(plan.entries[index].type, order_type))
         return(false);
   }

   return(true);
}

bool TradeExecutor_Execute(const PendingOrderPlan &plan, TradeExecutionResult &result)
{
   TradeExecutor_Reset(result);

   if(!TradeExecutor_IsPlanValid(plan))
      return(false);

   result.count = plan.count;

   for(int index = 0; index < plan.count; index++)
   {
      result.results[index].type = plan.entries[index].type;
      result.results[index].price = plan.entries[index].price;
      result.results[index].status = EXECUTION_STATUS_NOT_ATTEMPTED;
      result.results[index].retcode = 0;
      result.results[index].ticket = 0;

      ENUM_ORDER_TYPE order_type;
      TradeExecutor_MapOrderType(plan.entries[index].type, order_type);

      MqlTradeRequest request;
      MqlTradeResult response;
      ZeroMemory(request);
      ZeroMemory(response);

      request.action = TRADE_ACTION_PENDING;
      request.symbol = plan.symbol;
      request.volume = plan.volume;
      request.price = plan.entries[index].price;
      request.tp = plan.entries[index].take_profit;
      request.magic = plan.magic_number;
      request.comment = plan.comment;
      request.type = order_type;
      request.type_time = ORDER_TIME_GTC;
      request.type_filling = ORDER_FILLING_RETURN;

      bool sent = OrderSend(request, response);
      result.results[index].retcode = response.retcode;
      result.results[index].ticket = response.order;

      if(sent &&
         (response.retcode == TRADE_RETCODE_PLACED || response.retcode == TRADE_RETCODE_DONE))
         result.results[index].status = EXECUTION_STATUS_PLACED;
      else
         result.results[index].status = EXECUTION_STATUS_FAILED;
   }

   return(true);
}

bool TradeExecutor_CancelPendingOrder(const ulong ticket)
{
   if(ticket == 0)
      return(true);
   MqlTradeRequest request;
   MqlTradeResult response;
   ZeroMemory(request);
   ZeroMemory(response);
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   return(OrderSend(request, response) && response.retcode == TRADE_RETCODE_DONE);
}

void TradeExecutor_CancelSetupPendingOrders(const string symbol, const ulong magic_number, const string comment)
{
   for(int index = OrdersTotal() - 1; index >= 0; index--)
   {
      ulong ticket = OrderGetTicket(index);
      if(ticket == 0 ||
         OrderGetString(ORDER_SYMBOL) != symbol ||
         (ulong)OrderGetInteger(ORDER_MAGIC) != magic_number ||
         OrderGetString(ORDER_COMMENT) != comment)
         continue;

      TradeExecutor_CancelPendingOrder(ticket);
   }
}

#endif
