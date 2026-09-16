#ifndef MT5_AI_SIGNAL_VERIFICATION_MQH
#define MT5_AI_SIGNAL_VERIFICATION_MQH

#include "SignalReader.mqh"
#include "CandleFinder.mqh"
#include "Fibonacci.mqh"
#include "Constants.mqh"

const double SIGNAL_VERIFICATION_TOLERANCE = 0.000000001;

struct VerificationResult
{
   bool signal_valid;
   bool candle_valid;
   bool fibonacci_valid;
   bool orientation_valid;
   bool verification_passed;
};

void SignalVerification_Reset(VerificationResult &result)
{
   result.signal_valid = false;
   result.candle_valid = false;
   result.fibonacci_valid = false;
   result.orientation_valid = false;
   result.verification_passed = false;
}

bool SignalVerification_AreEqual(const double actual, const double expected)
{
   if(!MathIsValidNumber(actual) || !MathIsValidNumber(expected))
      return(false);

   const double scale = MathMax(1.0, MathMax(MathAbs(actual), MathAbs(expected)));
   return(MathAbs(actual - expected) <= SIGNAL_VERIFICATION_TOLERANCE * scale);
}

bool SignalVerification_LevelsAreValid(const FibonacciLevels &levels)
{
   return(
      MathIsValidNumber(levels.void_level) &&
      MathIsValidNumber(levels.bo) &&
      MathIsValidNumber(levels.tp) &&
      MathIsValidNumber(levels.tp_e4_e7) &&
      MathIsValidNumber(levels.e3) &&
      MathIsValidNumber(levels.e3_5) &&
      MathIsValidNumber(levels.e4) &&
      MathIsValidNumber(levels.e4_5) &&
      MathIsValidNumber(levels.e5) &&
      MathIsValidNumber(levels.e5_5) &&
      MathIsValidNumber(levels.e6) &&
      MathIsValidNumber(levels.e6_5) &&
      MathIsValidNumber(levels.e7) &&
      MathIsValidNumber(levels.e7_5) &&
      MathIsValidNumber(levels.e8) &&
      MathIsValidNumber(levels.e8_5) &&
      MathIsValidNumber(levels.e9) &&
      MathIsValidNumber(levels.e9_5) &&
      MathIsValidNumber(levels.e10)
   );
}

bool SignalVerification_LevelsMatchFormula(
   const FibonacciLevels &levels,
   const double anchor,
   const double range,
   const double orientation
)
{
   return(
      SignalVerification_AreEqual(levels.void_level, anchor + (range * FIBONACCI_RATIO_VOID * orientation)) &&
      SignalVerification_AreEqual(levels.bo, anchor + (range * FIBONACCI_RATIO_BO * orientation)) &&
      SignalVerification_AreEqual(levels.tp, anchor + (range * FIBONACCI_RATIO_TP * orientation)) &&
      SignalVerification_AreEqual(levels.tp_e4_e7, anchor + (range * FIBONACCI_RATIO_TP_E4_E7 * orientation)) &&
      SignalVerification_AreEqual(levels.e3, anchor + (range * FIBONACCI_RATIO_E3 * orientation)) &&
      SignalVerification_AreEqual(levels.e3_5, anchor + (range * FIBONACCI_RATIO_E3_5 * orientation)) &&
      SignalVerification_AreEqual(levels.e4, anchor + (range * FIBONACCI_RATIO_E4 * orientation)) &&
      SignalVerification_AreEqual(levels.e4_5, anchor + (range * FIBONACCI_RATIO_E4_5 * orientation)) &&
      SignalVerification_AreEqual(levels.e5, anchor + (range * FIBONACCI_RATIO_E5 * orientation)) &&
      SignalVerification_AreEqual(levels.e5_5, anchor + (range * FIBONACCI_RATIO_E5_5 * orientation)) &&
      SignalVerification_AreEqual(levels.e6, anchor + (range * FIBONACCI_RATIO_E6 * orientation)) &&
      SignalVerification_AreEqual(levels.e6_5, anchor + (range * FIBONACCI_RATIO_E6_5 * orientation)) &&
      SignalVerification_AreEqual(levels.e7, anchor + (range * FIBONACCI_RATIO_E7 * orientation)) &&
      SignalVerification_AreEqual(levels.e7_5, anchor + (range * FIBONACCI_RATIO_E7_5 * orientation)) &&
      SignalVerification_AreEqual(levels.e8, anchor + (range * FIBONACCI_RATIO_E8 * orientation)) &&
      SignalVerification_AreEqual(levels.e8_5, anchor + (range * FIBONACCI_RATIO_E8_5 * orientation)) &&
      SignalVerification_AreEqual(levels.e9, anchor + (range * FIBONACCI_RATIO_E9 * orientation)) &&
      SignalVerification_AreEqual(levels.e9_5, anchor + (range * FIBONACCI_RATIO_E9_5 * orientation)) &&
      SignalVerification_AreEqual(levels.e10, anchor + (range * FIBONACCI_RATIO_E10 * orientation))
   );
}

bool SignalVerification_Verify(
   const Signal &signal,
   const Candle &candle,
   const FibonacciLevels &levels,
   const SignalDirection direction,
   VerificationResult &result
)
{
   SignalVerification_Reset(result);

   result.signal_valid =
      signal.symbol != "" &&
      signal.timestamp > 0 &&
      signal.direction == direction &&
      (direction == SIGNAL_DIRECTION_BUY || direction == SIGNAL_DIRECTION_SELL);

   result.candle_valid =
      candle.time == signal.timestamp &&
      MathIsValidNumber(candle.high) &&
      MathIsValidNumber(candle.low) &&
      candle.high >= candle.low;

   if(result.candle_valid &&
      candle.high > candle.low &&
      (direction == SIGNAL_DIRECTION_BUY || direction == SIGNAL_DIRECTION_SELL) &&
      SignalVerification_LevelsAreValid(levels))
   {
      const double range = candle.high - candle.low;
      const double anchor = direction == SIGNAL_DIRECTION_BUY ? candle.high : candle.low;
      const double orientation = direction == SIGNAL_DIRECTION_BUY ? 1.0 : -1.0;

      result.fibonacci_valid = SignalVerification_LevelsMatchFormula(levels, anchor, range, orientation);

      if(direction == SIGNAL_DIRECTION_BUY)
         result.orientation_valid = SignalVerification_AreEqual(levels.e3, candle.high) &&
                                    levels.bo > levels.e3 &&
                                    levels.e4 < levels.e3;
      else
         result.orientation_valid = SignalVerification_AreEqual(levels.e3, candle.low) &&
                                    levels.bo < levels.e3 &&
                                    levels.e4 > levels.e3;
   }

   result.verification_passed =
      result.signal_valid &&
      result.candle_valid &&
      result.fibonacci_valid &&
      result.orientation_valid;

   return(result.verification_passed);
}

#endif
