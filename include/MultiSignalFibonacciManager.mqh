#ifndef MT5_AI_MULTI_SIGNAL_FIBONACCI_MANAGER_MQH
#define MT5_AI_MULTI_SIGNAL_FIBONACCI_MANAGER_MQH

#include "Constants.mqh"
#include "SignalReader.mqh"
#include "CandleFinder.mqh"
#include "Fibonacci.mqh"
#include "ChartDrawer.mqh"

enum SetupCompletionReason
{
   SETUP_COMPLETION_NONE,
   SETUP_COMPLETION_BO_TO_VOID,
   SETUP_COMPLETION_E3_TO_TP,
   SETUP_COMPLETION_E4_TO_TP_E4_E7,
   SETUP_COMPLETION_E5_TO_E3
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
   bool                  e3_visited;
   bool                  e4_visited;
   bool                  e5_visited;
   bool                  completed;
   SetupCompletionReason completion_reason;
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
   setup.e3_visited = false;
   setup.e4_visited = false;
   setup.e5_visited = false;
   setup.completed = false;
   setup.completion_reason = SETUP_COMPLETION_NONE;
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
   const SignalDirection direction
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
   g_signal_setups[slot].object_name = object_name;

   PrintFormat("[MT5-AI] Setup added: %s", object_name);
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

   if(SignalSetupManager_IsAtOrAbove(setup, bid, setup.levels.bo))
      setup.breakout_detected = true;

   if(SignalSetupManager_IsAtOrBelow(setup, bid, setup.levels.e3))
      setup.e3_visited = true;

   if(SignalSetupManager_IsAtOrBelow(setup, bid, setup.levels.e4))
      setup.e4_visited = true;

   if(SignalSetupManager_IsAtOrBelow(setup, bid, setup.levels.e5))
      setup.e5_visited = true;

   if(setup.breakout_detected && SignalSetupManager_IsAtOrAbove(setup, bid, setup.levels.void_level))
      SignalSetupManager_Complete(setup, SETUP_COMPLETION_BO_TO_VOID);
   else if(setup.e5_visited && SignalSetupManager_IsAtOrAbove(setup, bid, setup.levels.e3))
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
