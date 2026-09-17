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
   bool                  e3_visited;
   bool                  e4_visited;
   bool                  e5_visited;
   bool                  completed;
   SetupCompletionReason completion_reason;
   RangeClassification   classification;
   bool                  entry_orders_placed;
   ulong                 order_tickets[MAX_PENDING_ORDERS];
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
   setup.e3_visited = false;
   setup.e4_visited = false;
   setup.e5_visited = false;
   setup.completed = false;
   setup.completion_reason = SETUP_COMPLETION_NONE;
   setup.classification = RANGE_CLASSIFICATION_UNKNOWN;
   setup.entry_orders_placed = false;
   setup.order_ticket_count = 0;
   for(int index = 0; index < MAX_PENDING_ORDERS; index++)
      setup.order_tickets[index] = 0;
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

   PrintFormat("[MT5-AI] Setup added: %s", object_name);
   return(true);
}

bool SignalSetupManager_PlaceEntryOrders(SignalSetup &setup)
{
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

   TradeExecutionResult execution;
   if(!TradeExecutor_Execute(plan, execution))
      return(false);

   for(int index = 0; index < execution.count && index < MAX_PENDING_ORDERS; index++)
   {
      if(execution.results[index].status == EXECUTION_STATUS_PLACED)
         setup.order_tickets[setup.order_ticket_count++] = execution.results[index].ticket;
   }

   setup.entry_orders_placed = true;
   PrintFormat("[MT5-AI] Pullback orders placed: %s (%d orders)", setup.object_name, setup.order_ticket_count);
   return(true);
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

void SignalSetupManager_Complete(SignalSetup &setup, const SetupCompletionReason reason)
{
   if(setup.completed)
      return;

   for(int index = 0; index < setup.order_ticket_count; index++)
      TradeExecutor_CancelPendingOrder(setup.order_tickets[index]);

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

   double bid;
   if(!SymbolInfoDouble(setup.symbol, SYMBOL_BID, bid))
      return;

   datetime current_candle_time = iTime(setup.symbol, PERIOD_M1, 0);
   if(current_candle_time == 0)
      return;

   // The signal candle defines the Fibonacci. It is never a completion event.
   // Validation starts only after a later candle breaks BO or E4.
   if(!setup.breakout_detected)
   {
      if(current_candle_time <= setup.candle.time)
         return;

      if(SignalSetupManager_IsAtOrAbove(setup, bid, setup.levels.bo))
      {
         setup.breakout_detected = true;
         setup.breakout_type = SETUP_BREAKOUT_BO;
         setup.breakout_candle_time = current_candle_time;
         PrintFormat("[MT5-AI] Setup breakout: %s (BO)", setup.object_name);
         SignalSetupManager_PlaceEntryOrders(setup);
      }
      else if(SignalSetupManager_IsAtOrBelow(setup, bid, setup.levels.e4))
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
            setup.breakout_detected = false;
            setup.breakout_type = SETUP_BREAKOUT_NONE;
            PrintFormat("[MT5-AI] BUY Fibonacci flipped to SELL: %s", setup.object_name);
         }
      }

      return;
   }

   // Do not complete a setup on the same M1 candle that produced the breakout.
   if(current_candle_time <= setup.breakout_candle_time)
      return;

   // A BO breakout is committed to the BO -> VOID route. Pullback rules do
   // not apply to that setup unless it first breaks E4 instead.
   if(setup.breakout_type == SETUP_BREAKOUT_BO)
   {
      if(SignalSetupManager_IsAtOrAbove(setup, bid, setup.levels.void_level))
         SignalSetupManager_Complete(setup, SETUP_COMPLETION_BO_TO_VOID);

      return;
   }

   if(SignalSetupManager_IsAtOrBelow(setup, bid, setup.levels.e3))
      setup.e3_visited = true;

   if(SignalSetupManager_IsAtOrBelow(setup, bid, setup.levels.e4))
      setup.e4_visited = true;

   if(SignalSetupManager_IsAtOrBelow(setup, bid, setup.levels.e5))
      setup.e5_visited = true;

   if(setup.e5_visited && SignalSetupManager_IsAtOrAbove(setup, bid, setup.levels.e3))
      SignalSetupManager_Complete(setup, SETUP_COMPLETION_E5_TO_E3);
   else if(setup.e4_visited && SignalSetupManager_IsAtOrAbove(setup, bid, setup.levels.tp_e4_e7))
      SignalSetupManager_Complete(setup, SETUP_COMPLETION_E4_TO_TP_E4_E7);
   else if(setup.e3_visited && SignalSetupManager_IsAtOrAbove(setup, bid, setup.levels.tp))
      SignalSetupManager_Complete(setup, SETUP_COMPLETION_E3_TO_TP);
}

void SignalSetupManager_MonitorAll()
{
   for(int index = 0; index < MAX_ACTIVE_SIGNAL_SETUPS; index++)
      SignalSetupManager_MonitorSetup(g_signal_setups[index]);
}

#endif
