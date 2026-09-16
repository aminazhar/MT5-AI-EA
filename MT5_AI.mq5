#property copyright "MT5-AI-EA"
#property version   "1.0"
#property strict

#include "include/Config.mqh"
#include "include/Constants.mqh"
#include "include/SignalReader.mqh"
#include "include/CandleFinder.mqh"
#include "include/Fibonacci.mqh"
#include "include/SignalVerification.mqh"
#include "include/ChartDrawer.mqh"
#include "include/RangeFilter.mqh"
#include "include/BreakoutDetector.mqh"
#include "include/FibonacciReversal.mqh"
#include "include/PendingOrderPlanner.mqh"
#include "include/TradeExecutor.mqh"
#include "include/BasketManager.mqh"
#include "include/Utils.mqh"

int OnInit()
{
   EventSetTimer(TIMER_INTERVAL_SECONDS);
   Print("[MT5-AI] EA Initialized");

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("[MT5-AI] EA Stopped");
}

void OnTimer()
{
   Signal signal;

   if(SignalReader_Read(signal))
   {
      string direction_text = signal.direction == SIGNAL_DIRECTION_BUY ? "BUY" : "SELL";

      PrintFormat(
         "[MT5-AI] Signal: Symbol=%s Direction=%s Time=%s",
         signal.symbol,
         direction_text,
         TimeToString(signal.timestamp, TIME_DATE | TIME_SECONDS)
      );

      Candle candle;
      if(CandleFinder_FindM1(signal.symbol, signal.timestamp, candle))
      {
         PrintFormat(
            "[MT5-AI] Candle: Time=%s Open=%G High=%G Low=%G Close=%G TickVolume=%I64d",
            TimeToString(candle.time, TIME_DATE | TIME_SECONDS),
            candle.open,
            candle.high,
            candle.low,
            candle.close,
            candle.tick_volume
         );

         FibonacciLevels levels;
         if(Fibonacci_Calculate(candle, signal.direction, levels))
         {
             if(breakout.type != BREAKOUT_SELL && !ChartDrawer_DrawFibonacci(candle, signal.direction))
               Print("[MT5-AI] Fibonacci drawing failed");
               
            VerificationResult verification;
            SignalVerification_Verify(signal, candle, levels, signal.direction, verification);

            PrintFormat("[MT5-AI] Signal Verification: %s", verification.signal_valid ? "PASS" : "FAIL");
            PrintFormat("[MT5-AI] Candle Verification: %s", verification.candle_valid ? "PASS" : "FAIL");
            PrintFormat("[MT5-AI] Fibonacci Verification: %s", verification.fibonacci_valid ? "PASS" : "FAIL");
            PrintFormat("[MT5-AI] Orientation Verification: %s", verification.orientation_valid ? "PASS" : "FAIL");
            PrintFormat("[MT5-AI] Overall Verification: %s", verification.verification_passed ? "PASS" : "FAIL");

            PrintFormat(
               "[MT5-AI] Fibonacci: VOID=%G BO=%G TP=%G TP E4-E7=%G E3=%G E3.5=%G E4=%G",
               levels.void_level,
               levels.bo,
               levels.tp,
               levels.tp_e4_e7,
               levels.e3,
               levels.e3_5,
               levels.e4
            );

            PrintFormat(
               "[MT5-AI] Fibonacci: E4.5=%G E5=%G E5.5=%G E6=%G E6.5=%G E7=%G E7.5=%G",
               levels.e4_5,
               levels.e5,
               levels.e5_5,
               levels.e6,
               levels.e6_5,
               levels.e7,
               levels.e7_5
            );

            PrintFormat(
               "[MT5-AI] Fibonacci: E8=%G E8.5=%G E9=%G E9.5=%G E10=%G",
               levels.e8,
               levels.e8_5,
               levels.e9,
               levels.e9_5,
               levels.e10
            );

            double range;
            RangeClassification classification;
            if(RangeFilter_Classify(levels, range, classification))
            {
               string classification_name = classification == RANGE_CLASSIFICATION_REJECT ? "REJECT" :
                                            classification == RANGE_CLASSIFICATION_NORMAL ? "NORMAL" : "WIDE";

               PrintFormat(
                  "[MT5-AI] Range: Value=%G Classification=%s",
                  range,
                  classification_name
               );
            }
            else
            {
               Print("[MT5-AI] Range classification failed");
            }

            BreakoutResult breakout;
            if(BreakoutDetector_CheckBid(signal.symbol, levels, breakout))
            {
               FibonacciReversalResult reversal;
               bool reversal_successful = FibonacciReversal_Apply(signal, candle, breakout, reversal);

               if(reversal_successful && reversal.reversal_performed)
                  levels = reversal.levels;

               string breakout_type = breakout.type == BREAKOUT_BUY ? "BUY" :
                                      breakout.type == BREAKOUT_SELL ? "SELL" : "NONE";
               string reversal_required = breakout.fibonacci_reversal_required ? "YES" : "NO";

               PrintFormat(
                  "[MT5-AI] Breakout: Bid=%G Type=%s FibonacciReversalRequired=%s",
                  breakout.bid,
                  breakout_type,
                  reversal_required
               );

               PrintFormat("[MT5-AI] Reversal Triggered: %s", reversal.reversal_performed ? "YES" : "NO");
               PrintFormat("[MT5-AI] Fibonacci Recalculated: %s", reversal.reversal_performed ? "YES" : "NO");
               PrintFormat("[MT5-AI] Chart Redrawn: %s", reversal.redraw_successful ? "YES" : "NO");
               PrintFormat("[MT5-AI] Fibonacci Reversal Overall: %s", reversal_successful ? "PASS" : "FAIL");

               if(reversal_successful)
               {
                  PendingOrderPlan plan;
                  if(PendingOrderPlanner_Create(signal.direction, levels, classification, breakout, plan))
                  {
                     plan.symbol = signal.symbol;
                     plan.volume = InpOrderVolume;
                     plan.magic_number = InpMagicNumber;

                     PrintFormat("[MT5-AI] Pending order plan: Count=%d", plan.count);

                     for(int index = 0; index < plan.count; index++)
                     {
                     string order_type = plan.entries[index].type == PENDING_ORDER_BUY_STOP ? "BUY STOP" :
                                         plan.entries[index].type == PENDING_ORDER_BUY_LIMIT ? "BUY LIMIT" :
                                         plan.entries[index].type == PENDING_ORDER_SELL_STOP ? "SELL STOP" : "SELL LIMIT";

                     PrintFormat(
                        "[MT5-AI] Pending order: Type=%s Price=%G",
                        order_type,
                        plan.entries[index].price
                     );
                     }

                     TradeExecutionResult execution;
                     if(TradeExecutor_Execute(plan, execution))
                     {
                        for(int index = 0; index < execution.count; index++)
                        {
                        string execution_order_type = execution.results[index].type == PENDING_ORDER_BUY_STOP ? "BUY STOP" :
                                                      execution.results[index].type == PENDING_ORDER_BUY_LIMIT ? "BUY LIMIT" :
                                                      execution.results[index].type == PENDING_ORDER_SELL_STOP ? "SELL STOP" : "SELL LIMIT";
                        string execution_status = execution.results[index].status == EXECUTION_STATUS_PLACED ? "PLACED" :
                                                  execution.results[index].status == EXECUTION_STATUS_FAILED ? "FAILED" : "NOT ATTEMPTED";

                        PrintFormat(
                           "[MT5-AI] Execution: Type=%s Price=%G Status=%s Retcode=%u Ticket=%I64u",
                           execution_order_type,
                           execution.results[index].price,
                           execution_status,
                           execution.results[index].retcode,
                           execution.results[index].ticket
                        );
                        }

                        BasketConfiguration basket;
                        if(BasketManager_Create(levels, plan, execution, basket))
                        {
                        string basket_direction = basket.direction == BASKET_DIRECTION_BUY ? "BUY" :
                                                  basket.direction == BASKET_DIRECTION_SELL ? "SELL" : "NONE";

                        PrintFormat(
                           "[MT5-AI] Basket: Direction=%s PlacedOrderCount=%d TP=%G TP E4-E7=%G",
                           basket_direction,
                           basket.placed_order_count,
                           basket.take_profit,
                           basket.take_profit_e4_e7
                        );

                           for(int index = 0; index < basket.placed_order_count; index++)
                              PrintFormat("[MT5-AI] Basket ticket: %I64u", basket.tickets[index]);
                        }
                        else
                        {
                           Print("[MT5-AI] Basket configuration failed");
                        }
                     }
                     else
                     {
                        Print("[MT5-AI] Trade execution plan is invalid");
                     }
                  }
                  else
                  {
                     Print("[MT5-AI] Pending order planning failed");
                  }
               }
            }
            else
            {
               Print("[MT5-AI] Breakout detection failed");
            }

           
         }
         else
         {
            Print("[MT5-AI] Fibonacci calculation failed");
         }
      }
      else
      {
         Print("[MT5-AI] M1 candle not found");
      }
   }
}
