#ifndef MT5_AI_MULTI_SIGNAL_FIBONACCI_MANAGER_MQH
#define MT5_AI_MULTI_SIGNAL_FIBONACCI_MANAGER_MQH

#include "Constants.mqh"
#include "SignalReader.mqh"
#include "CandleFinder.mqh"
#include "Fibonacci.mqh"
#include "ChartDrawer.mqh"
#include "RangeFilter.mqh"
#include "PendingOrderPlanner.mqh"
#include "TradeExecutor.mqh"
#include "Config.mqh"

enum SetupCompletionReason
{
   SETUP_COMPLETION_NONE,
   SETUP_COMPLETION_BO_TO_VOID,
   SETUP_COMPLETION_E3_TO_TP,
   SETUP_COMPLETION_E4_TO_TP_E4_E7,
   SETUP_COMPLETION_E5_TO_E3
};

enum SetupBreakoutType
{
   SETUP_BREAKOUT_NONE,
   SETUP_BREAKOUT_BO,
   SETUP_BREAKOUT_E4
};

enum HistoricalRecoveryState
{
   HISTORICAL_RECOVERY_NONE,
   HISTORICAL_RECOVERY_BO_ACTIVE,
   HISTORICAL_RECOVERY_COMPLETED
};

HistoricalRecoveryState SignalSetupManager_ScanBuyHistory(
   const string symbol,
   const datetime signal_time,
   const FibonacciLevels &levels,
   datetime &breakout_time
)
{
   breakout_time = 0;
   MqlRates candles[];
   datetime last_closed_candle = iTime(symbol, PERIOD_M1, 1);
   if(last_closed_candle == 0 || last_closed_candle <= signal_time)
      return(HISTORICAL_RECOVERY_NONE);

   int copied = CopyRates(symbol, PERIOD_M1, signal_time + 60, last_closed_candle, candles);
   if(copied <= 0)
      return(HISTORICAL_RECOVERY_NONE);

   bool bo_broken = false;
   for(int index = 0; index < copied; index++)
   {
      if(!bo_broken && candles[index].high >= levels.bo)
      {
         bo_broken = true;
         breakout_time = candles[index].time;
         // The breakout candle only arms the route. Completion validation
         // begins with the following closed M1 candle.
         continue;
      }

      if(bo_broken && candles[index].high >= levels.void_level)
         return(HISTORICAL_RECOVERY_COMPLETED);
   }

   return(bo_broken ? HISTORICAL_RECOVERY_BO_ACTIVE : HISTORICAL_RECOVERY_NONE);
}

struct SignalSetup
{
   bool                  in_use;
   string                symbol;
   datetime              timestamp;
   Candle                candle;
   FibonacciLevels       levels;
   SignalDirection       direction;
   string                object_name;
   bool                  breakout_detected;
   SetupBreakoutType     breakout_type;
   datetime              breakout_candle_time;
   datetime              last_evaluated_candle_time;
   bool                  e3_visited;
   bool                  e4_visited;
   bool                  e5_visited;
   bool                  e4_target_moved_to_e3;
   bool                  completed;
   SetupCompletionReason completion_reason;
   RangeClassification   classification;
   bool                  entry_orders_placed;
   bool                  breakout_stop_placement_attempted;
   bool                  breakout_stop_orders_placed;
   bool                  breakout_stop_triggered;
   ulong                 breakout_buy_stop_ticket;
   ulong                 breakout_sell_stop_ticket;
   bool                  recovered_from_history;
   bool                  recovered_level_touched[MAX_PENDING_ORDERS];
   ulong                 order_tickets[MAX_PENDING_ORDERS];
   ulong                 position_ids[MAX_PENDING_ORDERS];
   double                order_targets[MAX_PENDING_ORDERS];
   int                   order_ticket_count;
};

SignalSetup g_signal_setups[MAX_ACTIVE_SIGNAL_SETUPS];

void SignalSetupManager_Reset(SignalSetup &setup)
{
   setup.in_use = false;
   setup.symbol = "";
   setup.timestamp = 0;
   setup.direction = SIGNAL_DIRECTION_UNKNOWN;
   setup.object_name = "";
   setup.breakout_detected = false;
   setup.breakout_type = SETUP_BREAKOUT_NONE;
   setup.breakout_candle_time = 0;
   setup.last_evaluated_candle_time = 0;
   setup.e3_visited = false;
   setup.e4_visited = false;
   setup.e5_visited = false;
   setup.e4_target_moved_to_e3 = false;
   setup.completed = false;
   setup.completion_reason = SETUP_COMPLETION_NONE;
   setup.classification = RANGE_CLASSIFICATION_UNKNOWN;
   setup.entry_orders_placed = false;
   setup.breakout_stop_placement_attempted = false;
   setup.breakout_stop_orders_placed = false;
   setup.breakout_stop_triggered = false;
   setup.breakout_buy_stop_ticket = 0;
   setup.breakout_sell_stop_ticket = 0;
   setup.recovered_from_history = false;
   setup.order_ticket_count = 0;
   for(int index = 0; index < MAX_PENDING_ORDERS; index++)
   {
      setup.order_tickets[index] = 0;
      setup.recovered_level_touched[index] = false;
      setup.position_ids[index] = 0;
      setup.order_targets[index] = 0.0;
   }
   Fibonacci_Reset(setup.levels);
}

void SignalSetupManager_Initialize()
{
   for(int index = 0; index < MAX_ACTIVE_SIGNAL_SETUPS; index++)
      SignalSetupManager_Reset(g_signal_setups[index]);
}

int SignalSetupManager_Find(const string symbol, const datetime timestamp)
{
   for(int index = 0; index < MAX_ACTIVE_SIGNAL_SETUPS; index++)
   {
      if(g_signal_setups[index].in_use &&
         g_signal_setups[index].symbol == symbol &&
         g_signal_setups[index].timestamp == timestamp)
         return(index);
   }

   return(-1);
}

int SignalSetupManager_FindAvailableSlot()
{
   for(int index = 0; index < MAX_ACTIVE_SIGNAL_SETUPS; index++)
   {
      if(!g_signal_setups[index].in_use)
         return(index);
   }

   for(int index = 0; index < MAX_ACTIVE_SIGNAL_SETUPS; index++)
   {
      if(g_signal_setups[index].completed)
         return(index);
   }

   return(-1);
}

string SignalSetupManager_ObjectName(const Signal &signal)
{
   return(FIBONACCI_OBJECT_PREFIX + signal.symbol + "_" + IntegerToString((long)signal.timestamp));
}

bool SignalSetupManager_Add(
   const Signal &signal,
   const Candle &candle,
   const FibonacciLevels &levels,
   const SignalDirection direction,
   const RangeClassification classification
)
{
   if(SignalSetupManager_Find(signal.symbol, signal.timestamp) >= 0)
      return(true);

   int slot = SignalSetupManager_FindAvailableSlot();
   if(slot < 0)
   {
      Print("[MT5-AI] Multi-signal capacity reached; signal ignored");
      return(false);
   }

   string object_name = SignalSetupManager_ObjectName(signal);
   if(!ChartDrawer_DrawFibonacci(object_name, candle, direction))
      return(false);

   SignalSetupManager_Reset(g_signal_setups[slot]);
   g_signal_setups[slot].in_use = true;
   g_signal_setups[slot].symbol = signal.symbol;
   g_signal_setups[slot].timestamp = signal.timestamp;
   g_signal_setups[slot].candle = candle;
   g_signal_setups[slot].levels = levels;
   g_signal_setups[slot].direction = direction;
   g_signal_setups[slot].classification = classification;
   g_signal_setups[slot].object_name = object_name;
   // The signal candle defines the Fibonacci only. Evaluation begins with
   // the following fully closed M1 candle.
   g_signal_setups[slot].last_evaluated_candle_time = candle.time;

   PrintFormat("[MT5-AI] Setup added: %s", object_name);
   return(true);
}

string SignalSetupManager_OrderComment(const SignalSetup &setup)
{
   return("MT5AI_" + IntegerToString((long)setup.timestamp) + "_" +
          (setup.direction == SIGNAL_DIRECTION_BUY ? "B" : "S"));
}

string SignalSetupManager_BreakoutStopOrderComment(const SignalSetup &setup)
{
   return("MT5BO_" + IntegerToString((long)setup.timestamp));
}

void SignalSetupManager_MarkRecoveryTouchedLevels(SignalSetup &setup, const datetime breakout_time)
{
   MqlRates candles[];
   datetime last_closed_candle = iTime(setup.symbol, PERIOD_M1, 1);
   if(last_closed_candle <= breakout_time ||
      CopyRates(setup.symbol, PERIOD_M1, breakout_time + 60, last_closed_candle, candles) <= 0)
      return;

   for(int index = 0; index < ArraySize(candles); index++)
   {
      setup.recovered_level_touched[0] = setup.recovered_level_touched[0] || candles[index].low <= setup.levels.bo;
      setup.recovered_level_touched[1] = setup.recovered_level_touched[1] || candles[index].low <= setup.levels.e3;
      setup.recovered_level_touched[2] = setup.recovered_level_touched[2] || candles[index].low <= setup.levels.e4;
      setup.recovered_level_touched[3] = setup.recovered_level_touched[3] || candles[index].low <= setup.levels.e5;
      setup.recovered_level_touched[4] = setup.recovered_level_touched[4] || candles[index].low <= setup.levels.e6;
      setup.recovered_level_touched[5] = setup.recovered_level_touched[5] || candles[index].low <= setup.levels.e7;
      setup.recovered_level_touched[6] = setup.recovered_level_touched[6] || candles[index].low <= setup.levels.e8;
      setup.recovered_level_touched[7] = setup.recovered_level_touched[7] || candles[index].low <= setup.levels.e9;
      setup.recovered_level_touched[8] = setup.recovered_level_touched[8] || candles[index].low <= setup.levels.e10;
   }
}

bool SignalSetupManager_IsRecoveredLevelTouched(const SignalSetup &setup, const double price)
{
   if(!setup.recovered_from_history)
      return(false);

   return((price == setup.levels.bo && setup.recovered_level_touched[0]) ||
          (price == setup.levels.e3 && setup.recovered_level_touched[1]) ||
          (price == setup.levels.e4 && setup.recovered_level_touched[2]) ||
          (price == setup.levels.e5 && setup.recovered_level_touched[3]) ||
          (price == setup.levels.e6 && setup.recovered_level_touched[4]) ||
          (price == setup.levels.e7 && setup.recovered_level_touched[5]) ||
          (price == setup.levels.e8 && setup.recovered_level_touched[6]) ||
          (price == setup.levels.e9 && setup.recovered_level_touched[7]) ||
          (price == setup.levels.e10 && setup.recovered_level_touched[8]));
}

bool SignalSetupManager_PlaceEntryOrders(SignalSetup &setup)
{
   if(!InpEnableAutoTrade)
      return(false);

   if(setup.entry_orders_placed || InpOrderVolume <= 0.0)
      return(setup.entry_orders_placed);

   BreakoutResult breakout;
   BreakoutDetector_Reset(breakout);
   breakout.type = setup.direction == SIGNAL_DIRECTION_BUY ? BREAKOUT_BUY : BREAKOUT_SELL;

   PendingOrderPlan plan;
   if(!PendingOrderPlanner_Create(setup.direction, setup.levels, setup.classification, breakout, plan))
      return(false);

   plan.symbol = setup.symbol;
   plan.volume = InpOrderVolume;
   plan.magic_number = InpMagicNumber;
   plan.comment = SignalSetupManager_OrderComment(setup);

   PendingOrderPlan filtered_plan;
   PendingOrderPlanner_Reset(filtered_plan);
   filtered_plan.symbol = plan.symbol;
   filtered_plan.volume = plan.volume;
   filtered_plan.magic_number = plan.magic_number;
   filtered_plan.comment = plan.comment;
   for(int index = 0; index < plan.count; index++)
   {
      // An E4-triggered flip enters on SELL pullbacks. Its own SELL BO has
      // not broken and is not an entry level for this route.
      if(setup.breakout_type == SETUP_BREAKOUT_E4 && plan.entries[index].price == setup.levels.bo)
         continue;

      if(!SignalSetupManager_IsRecoveredLevelTouched(setup, plan.entries[index].price))
         PendingOrderPlanner_Add(filtered_plan, plan.entries[index].type, plan.entries[index].price, plan.entries[index].take_profit);
   }

   TradeExecutionResult execution;
   if(!TradeExecutor_Execute(filtered_plan, execution))
      return(false);

   for(int index = 0; index < execution.count && index < MAX_PENDING_ORDERS; index++)
   {
      if(execution.results[index].status == EXECUTION_STATUS_PLACED)
      {
         int layer = setup.order_ticket_count++;
         setup.order_tickets[layer] = execution.results[index].ticket;
         setup.order_targets[layer] = filtered_plan.entries[index].take_profit;
      }
      else
      {
         PrintFormat(
            "[MT5-AI] Pending order rejected: %s price=%G TP=%G retcode=%u",
            setup.object_name,
            filtered_plan.entries[index].price,
            filtered_plan.entries[index].take_profit,
            execution.results[index].retcode
         );
      }
   }

   setup.entry_orders_placed = setup.order_ticket_count > 0;
   if(!setup.entry_orders_placed)
   {
      PrintFormat("[MT5-AI] No pending orders were accepted: %s", setup.object_name);
      return(false);
   }

   PrintFormat("[MT5-AI] Pullback orders placed: %s (%d orders)", setup.object_name, setup.order_ticket_count);
   return(true);
}

bool SignalSetupManager_PlaceBreakoutStopOrders(SignalSetup &setup)
{
   if(!InpEnableFiboBreakoutStops ||
      setup.breakout_stop_placement_attempted ||
      InpOrderVolume <= 0.0)
      return(false);

   // Do not let the signal candle itself activate either breakout stop.
   datetime current_candle_time = iTime(setup.symbol, PERIOD_M1, 0);
   if(current_candle_time == 0 || current_candle_time <= setup.candle.time)
      return(false);

   if(current_candle_time > setup.candle.time + PeriodSeconds(PERIOD_M1))
   {
      setup.breakout_stop_placement_attempted = true;
      PrintFormat(
         "[MT5-AI] Breakout stops not armed for stale signal: %s (signal=%s)",
         setup.object_name,
         TimeToString(setup.candle.time, TIME_DATE | TIME_MINUTES)
      );
      return(false);
   }

   setup.breakout_stop_placement_attempted = true;

   PendingOrderPlan plan;
   if(!PendingOrderPlanner_CreateBreakoutStopPlan(setup.levels, plan))
      return(false);

   plan.symbol = setup.symbol;
   plan.volume = InpOrderVolume;
   plan.magic_number = InpMagicNumber;
   plan.comment = SignalSetupManager_BreakoutStopOrderComment(setup);

   TradeExecutionResult execution;
   if(!TradeExecutor_Execute(plan, execution))
      return(false);

   for(int index = 0; index < execution.count; index++)
   {
      if(execution.results[index].status == EXECUTION_STATUS_PLACED)
      {
         if(plan.entries[index].type == PENDING_ORDER_BUY_STOP)
            setup.breakout_buy_stop_ticket = execution.results[index].ticket;
         else if(plan.entries[index].type == PENDING_ORDER_SELL_STOP)
            setup.breakout_sell_stop_ticket = execution.results[index].ticket;

         continue;
      }

      PrintFormat(
         "[MT5-AI] Breakout stop rejected: %s type=%d price=%G retcode=%u",
         setup.object_name,
         plan.entries[index].type,
         plan.entries[index].price,
         execution.results[index].retcode
      );
   }

   if(setup.breakout_buy_stop_ticket == 0 || setup.breakout_sell_stop_ticket == 0)
   {
      TradeExecutor_CancelPendingOrder(setup.breakout_buy_stop_ticket);
      TradeExecutor_CancelPendingOrder(setup.breakout_sell_stop_ticket);
      setup.breakout_buy_stop_ticket = 0;
      setup.breakout_sell_stop_ticket = 0;
      PrintFormat("[MT5-AI] Breakout-stop pair was not armed: %s", setup.object_name);
      return(false);
   }

   setup.breakout_stop_orders_placed = true;
   PrintFormat(
      "[MT5-AI] Breakout stops armed: %s (BUY STOP=%G, SELL STOP=%G; manual TP/SL)",
      setup.object_name,
      setup.levels.bo,
      setup.levels.e4
   );
   return(true);
}

bool SignalSetupManager_FlipBreakoutStopSetupToSell(SignalSetup &setup)
{
   FibonacciLevels sell_levels;
   string sell_object_name = setup.object_name + "_SELL";
   if(!Fibonacci_Calculate(setup.candle, SIGNAL_DIRECTION_SELL, sell_levels) ||
      !ChartDrawer_RemoveFibonacci(setup.object_name) ||
      !ChartDrawer_DrawFibonacci(sell_object_name, setup.candle, SIGNAL_DIRECTION_SELL))
   {
      PrintFormat("[MT5-AI] Could not flip breakout-stop Fibonacci: %s", setup.object_name);
      return(false);
   }

   setup.levels = sell_levels;
   setup.direction = SIGNAL_DIRECTION_SELL;
   setup.object_name = sell_object_name;
   return(true);
}

void SignalSetupManager_HandleBreakoutStopTrigger(SignalSetup &setup, const ulong order_ticket)
{
   if(!InpEnableFiboBreakoutStops ||
      !setup.breakout_stop_orders_placed ||
      setup.breakout_stop_triggered)
      return;

   bool buy_stop_triggered = order_ticket == setup.breakout_buy_stop_ticket;
   bool sell_stop_triggered = order_ticket == setup.breakout_sell_stop_ticket;
   if(!buy_stop_triggered && !sell_stop_triggered)
      return;

   setup.breakout_stop_triggered = true;
   setup.breakout_detected = true;
   setup.breakout_candle_time = iTime(setup.symbol, PERIOD_M1, 0);

   ulong opposite_ticket = buy_stop_triggered ?
                           setup.breakout_sell_stop_ticket : setup.breakout_buy_stop_ticket;
   if(!TradeExecutor_CancelPendingOrder(opposite_ticket))
      PrintFormat("[MT5-AI] Could not cancel opposite breakout stop: ticket=%I64u", opposite_ticket);

   if(buy_stop_triggered)
   {
      setup.breakout_type = SETUP_BREAKOUT_BO;
      PrintFormat("[MT5-AI] BUY STOP triggered; SELL STOP cancelled: %s", setup.object_name);
      return;
   }

   setup.breakout_type = SETUP_BREAKOUT_E4;
   if(SignalSetupManager_FlipBreakoutStopSetupToSell(setup))
      PrintFormat("[MT5-AI] SELL STOP triggered; BUY STOP cancelled and Fibonacci flipped: %s", setup.object_name);
}

void SignalSetupManager_OnTradeTransaction(const MqlTradeTransaction &transaction)
{
   if(transaction.type != TRADE_TRANSACTION_DEAL_ADD || transaction.deal == 0)
      return;

   ulong order_ticket = (ulong)HistoryDealGetInteger(transaction.deal, DEAL_ORDER);
   ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(transaction.deal, DEAL_ENTRY);
   if(order_ticket == 0 ||
      (deal_entry != DEAL_ENTRY_IN && deal_entry != DEAL_ENTRY_INOUT))
      return;

   if(InpEnableFiboBreakoutStops)
   {
      for(int setup_index = 0; setup_index < MAX_ACTIVE_SIGNAL_SETUPS; setup_index++)
      {
         if(order_ticket != g_signal_setups[setup_index].breakout_buy_stop_ticket &&
            order_ticket != g_signal_setups[setup_index].breakout_sell_stop_ticket)
            continue;

         SignalSetupManager_HandleBreakoutStopTrigger(g_signal_setups[setup_index], order_ticket);
         return;
      }
   }

   ulong position_id = (ulong)HistoryDealGetInteger(transaction.deal, DEAL_POSITION_ID);
   if(order_ticket == 0 || position_id == 0)
      return;

   for(int setup_index = 0; setup_index < MAX_ACTIVE_SIGNAL_SETUPS; setup_index++)
   {
      for(int layer = 0; layer < g_signal_setups[setup_index].order_ticket_count; layer++)
      {
         if(g_signal_setups[setup_index].order_tickets[layer] == order_ticket)
            g_signal_setups[setup_index].position_ids[layer] = position_id;
      }
   }
}

void SignalSetupManager_Complete(SignalSetup &setup, const SetupCompletionReason reason);

void SignalSetupManager_MonitorFallbackExits(SignalSetup &setup)
{
   double bid;
   double ask;
   if(!SymbolInfoDouble(setup.symbol, SYMBOL_BID, bid) || !SymbolInfoDouble(setup.symbol, SYMBOL_ASK, ask))
      return;

   for(int layer = 0; layer < setup.order_ticket_count; layer++)
   {
      if(setup.position_ids[layer] == 0 || setup.order_targets[layer] <= 0.0)
         continue;

      for(int position_index = PositionsTotal() - 1; position_index >= 0; position_index--)
      {
         ulong position_ticket = PositionGetTicket(position_index);
         if(position_ticket == 0 ||
            (ulong)PositionGetInteger(POSITION_IDENTIFIER) != setup.position_ids[layer])
            continue;

         bool target_hit = setup.direction == SIGNAL_DIRECTION_BUY ?
                           bid >= setup.order_targets[layer] : ask <= setup.order_targets[layer];
         if(!target_hit)
            continue;

         SignalSetupManager_Complete(setup, SETUP_COMPLETION_NONE);
         return;
      }
   }
}

bool SignalSetupManager_IsAtOrAbove(const SignalSetup &setup, const double price, const double level)
{
   return(setup.direction == SIGNAL_DIRECTION_BUY ? price >= level : price <= level);
}

bool SignalSetupManager_IsAtOrBelow(const SignalSetup &setup, const double price, const double level)
{
   return(setup.direction == SIGNAL_DIRECTION_BUY ? price <= level : price >= level);
}

string SignalSetupManager_CompletionReasonName(const SetupCompletionReason reason)
{
   if(reason == SETUP_COMPLETION_BO_TO_VOID)
      return("BO->VOID");
   if(reason == SETUP_COMPLETION_E3_TO_TP)
      return("E3->TP");
   if(reason == SETUP_COMPLETION_E4_TO_TP_E4_E7)
      return("E4->TP E4-E7");
   if(reason == SETUP_COMPLETION_E5_TO_E3)
      return("E5/deeper->E3");

   return("NONE");
}

void SignalSetupManager_CloseTrackedPositions(SignalSetup &setup)
{
   for(int position_index = PositionsTotal() - 1; position_index >= 0; position_index--)
   {
      ulong position_ticket = PositionGetTicket(position_index);
      if(position_ticket == 0)
         continue;

      ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool belongs_to_setup = PositionGetString(POSITION_COMMENT) == SignalSetupManager_OrderComment(setup);
      for(int layer = 0; layer < setup.order_ticket_count; layer++)
      {
         if(setup.position_ids[layer] == position_id)
         {
            belongs_to_setup = true;
            break;
         }
      }
      if(!belongs_to_setup)
         continue;

      MqlTradeRequest request;
      MqlTradeResult response;
      ZeroMemory(request);
      ZeroMemory(response);
      request.action = TRADE_ACTION_DEAL;
      request.position = position_ticket;
      request.symbol = setup.symbol;
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.type = setup.direction == SIGNAL_DIRECTION_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = setup.direction == SIGNAL_DIRECTION_BUY ? SymbolInfoDouble(setup.symbol, SYMBOL_BID) : SymbolInfoDouble(setup.symbol, SYMBOL_ASK);
      request.magic = InpMagicNumber;
      if(!OrderSend(request, response))
         PrintFormat("[MT5-AI] Basket close failed: position=%I64u retcode=%u", position_ticket, response.retcode);
   }
}

void SignalSetupManager_MoveE4TargetToE3(SignalSetup &setup)
{
   if(setup.e4_target_moved_to_e3)
      return;

   for(int layer = 0; layer < setup.order_ticket_count; layer++)
   {
      if(setup.order_targets[layer] != setup.levels.tp_e4_e7)
         continue;

      setup.order_targets[layer] = setup.levels.e3;
      for(int position_index = PositionsTotal() - 1; position_index >= 0; position_index--)
      {
         ulong position_ticket = PositionGetTicket(position_index);
         if(position_ticket == 0 ||
            (ulong)PositionGetInteger(POSITION_IDENTIFIER) != setup.position_ids[layer])
            continue;

         MqlTradeRequest request;
         MqlTradeResult response;
         ZeroMemory(request);
         ZeroMemory(response);
         request.action = TRADE_ACTION_SLTP;
         request.position = position_ticket;
         request.symbol = setup.symbol;
         request.tp = setup.levels.e3;
         if(!OrderSend(request, response))
            PrintFormat("[MT5-AI] E4 TP move to E3 failed: position=%I64u retcode=%u", position_ticket, response.retcode);
      }
   }

   setup.e4_target_moved_to_e3 = true;
   PrintFormat("[MT5-AI] E5 reached: E4 target moved to E3 for %s", setup.object_name);
}

void SignalSetupManager_Complete(SignalSetup &setup, const SetupCompletionReason reason)
{
   if(setup.completed)
      return;

   SignalSetupManager_CloseTrackedPositions(setup);

   for(int index = 0; index < setup.order_ticket_count; index++)
      TradeExecutor_CancelPendingOrder(setup.order_tickets[index]);
   TradeExecutor_CancelSetupPendingOrders(setup.symbol, InpMagicNumber, SignalSetupManager_OrderComment(setup));

   if(!ChartDrawer_RemoveFibonacci(setup.object_name))
   {
      PrintFormat("[MT5-AI] Could not remove completed setup: %s", setup.object_name);
      return;
   }

   setup.completed = true;
   setup.completion_reason = reason;
   PrintFormat(
      "[MT5-AI] Setup completed and Fibonacci removed: %s (%s)",
      setup.object_name,
      SignalSetupManager_CompletionReasonName(reason)
   );
}

void SignalSetupManager_MonitorSetup(SignalSetup &setup)
{
   if(!setup.in_use || setup.completed)
      return;

   SignalSetupManager_MonitorFallbackExits(setup);
   if(setup.completed)
      return;

   if(InpEnableFiboBreakoutStops)
   {
      SignalSetupManager_PlaceBreakoutStopOrders(setup);
      return;
   }

   if(!InpEnableAutoTrade)
      return;

   datetime last_closed_candle_time = iTime(setup.symbol, PERIOD_M1, 1);
   if(last_closed_candle_time == 0 ||
      last_closed_candle_time <= setup.last_evaluated_candle_time)
      return;

   MqlRates closed_candles[];
   int copied = CopyRates(
      setup.symbol,
      PERIOD_M1,
      setup.last_evaluated_candle_time + PeriodSeconds(PERIOD_M1),
      last_closed_candle_time,
      closed_candles
   );
   if(copied <= 0)
      return;

   // Process every missed closed candle chronologically. This preserves the
   // first valid route after the signal: BO wins if it occurred before E4.
   for(int index = 0; index < copied; index++)
   {
      datetime closed_candle_time = closed_candles[index].time;
      if(closed_candle_time <= setup.last_evaluated_candle_time ||
         closed_candle_time <= setup.candle.time)
         continue;

      double closed_high = closed_candles[index].high;
      double closed_low = closed_candles[index].low;
      double closed_price = closed_candles[index].close;
      if(closed_high <= 0.0 || closed_low <= 0.0 || closed_price <= 0.0)
         continue;

      setup.last_evaluated_candle_time = closed_candle_time;

      // The signal candle defines the Fibonacci. It is never a breakout or
      // completion event. Only later, fully closed candles reach this point.
      if(!setup.breakout_detected)
      {
         // Route selection is close-confirmed: a wick through BO or E4 does
         // not place orders or flip the Fibonacci.
         bool bo_broken = setup.direction == SIGNAL_DIRECTION_BUY ?
                           closed_price >= setup.levels.bo : closed_price <= setup.levels.bo;
         bool e4_broken = setup.direction == SIGNAL_DIRECTION_BUY ?
                           closed_price <= setup.levels.e4 : closed_price >= setup.levels.e4;

         if(bo_broken)
         {
            setup.breakout_detected = true;
            setup.breakout_type = SETUP_BREAKOUT_BO;
            setup.breakout_candle_time = closed_candle_time;
            PrintFormat(
               "[MT5-AI] Setup breakout: %s (BO close; candle=%s high=%G low=%G close=%G BO=%G)",
               setup.object_name,
               TimeToString(closed_candle_time, TIME_DATE | TIME_MINUTES),
               closed_high,
               closed_low,
               closed_price,
               setup.levels.bo
            );
            SignalSetupManager_PlaceEntryOrders(setup);
            return;
         }

         if(e4_broken && setup.direction == SIGNAL_DIRECTION_BUY)
         {
            FibonacciLevels sell_levels;
            string sell_object_name = setup.object_name + "_SELL";
            if(Fibonacci_Calculate(setup.candle, SIGNAL_DIRECTION_SELL, sell_levels) &&
               ChartDrawer_RemoveFibonacci(setup.object_name) &&
               ChartDrawer_DrawFibonacci(sell_object_name, setup.candle, SIGNAL_DIRECTION_SELL))
            {
               setup.levels = sell_levels;
               setup.direction = SIGNAL_DIRECTION_SELL;
               setup.object_name = sell_object_name;
               setup.breakout_detected = true;
               setup.breakout_type = SETUP_BREAKOUT_E4;
               setup.breakout_candle_time = closed_candle_time;
               PrintFormat(
                  "[MT5-AI] BUY Fibonacci flipped to SELL: %s (E4 close; candle=%s high=%G low=%G close=%G BUY E4=%G)",
                  setup.object_name,
                  TimeToString(closed_candle_time, TIME_DATE | TIME_MINUTES),
                  closed_high,
                  closed_low,
                  closed_price,
                  setup.candle.high + ((setup.candle.high - setup.candle.low) * FIBONACCI_RATIO_E4)
               );
               SignalSetupManager_PlaceEntryOrders(setup);
            }

            return;
         }

         continue;
      }

      // Do not complete a setup on the same M1 candle that produced the breakout.
      if(closed_candle_time <= setup.breakout_candle_time)
         continue;

      bool entry_level_touched = setup.direction == SIGNAL_DIRECTION_BUY ?
                                 closed_low <= setup.levels.e3 : closed_high >= setup.levels.e3;
      bool e4_level_touched = setup.direction == SIGNAL_DIRECTION_BUY ?
                              closed_low <= setup.levels.e4 : closed_high >= setup.levels.e4;
      bool e5_level_touched = setup.direction == SIGNAL_DIRECTION_BUY ?
                              closed_low <= setup.levels.e5 : closed_high >= setup.levels.e5;

      // A BO breakout is committed to the BO -> VOID route. Pullback rules do
      // not apply to that setup unless it first breaks E4 instead.
      if(setup.breakout_type == SETUP_BREAKOUT_BO)
      {
         if(SignalSetupManager_IsAtOrAbove(setup, setup.direction == SIGNAL_DIRECTION_BUY ? closed_high : closed_low, setup.levels.void_level))
            SignalSetupManager_Complete(setup, SETUP_COMPLETION_BO_TO_VOID);

         if(setup.completed)
            return;

         continue;
      }

      if(entry_level_touched)
         setup.e3_visited = true;

      if(e4_level_touched)
         setup.e4_visited = true;

      if(e5_level_touched)
      {
         setup.e5_visited = true;
         SignalSetupManager_MoveE4TargetToE3(setup);
      }

      double target_price = setup.direction == SIGNAL_DIRECTION_BUY ? closed_high : closed_low;
      if(setup.e5_visited && SignalSetupManager_IsAtOrAbove(setup, target_price, setup.levels.e3))
         SignalSetupManager_Complete(setup, SETUP_COMPLETION_E5_TO_E3);
      else if(setup.e4_visited && SignalSetupManager_IsAtOrAbove(setup, target_price, setup.levels.tp_e4_e7))
         SignalSetupManager_Complete(setup, SETUP_COMPLETION_E4_TO_TP_E4_E7);
      else if(setup.e3_visited && SignalSetupManager_IsAtOrAbove(setup, target_price, setup.levels.tp))
         SignalSetupManager_Complete(setup, SETUP_COMPLETION_E3_TO_TP);

      if(setup.completed)
         return;
   }
}

void SignalSetupManager_MonitorAll()
{
   for(int index = 0; index < MAX_ACTIVE_SIGNAL_SETUPS; index++)
      SignalSetupManager_MonitorSetup(g_signal_setups[index]);
}

#endif
