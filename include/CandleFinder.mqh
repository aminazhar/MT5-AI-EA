#ifndef MT5_AI_CANDLE_FINDER_MQH
#define MT5_AI_CANDLE_FINDER_MQH

struct Candle
{
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
   long     tick_volume;
};

void CandleFinder_Reset(Candle &candle)
{
   candle.time        = 0;
   candle.open        = 0.0;
   candle.high        = 0.0;
   candle.low         = 0.0;
   candle.close       = 0.0;
   candle.tick_volume = 0;
}

bool CandleFinder_FindM1(const string symbol, const datetime timestamp, Candle &candle)
{
   CandleFinder_Reset(candle);

   if(symbol == "" || timestamp == 0)
      return(false);

   int bar_shift = iBarShift(symbol, PERIOD_M1, timestamp, true);
   if(bar_shift < 0)
      return(false);

   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, bar_shift, 1, rates) != 1)
      return(false);

   if(rates[0].time != timestamp)
      return(false);

   candle.time        = rates[0].time;
   candle.open        = rates[0].open;
   candle.high        = rates[0].high;
   candle.low         = rates[0].low;
   candle.close       = rates[0].close;
   candle.tick_volume = rates[0].tick_volume;

   return(true);
}

#endif
