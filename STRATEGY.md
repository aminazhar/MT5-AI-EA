# Trading Strategy

## Signal

Telegram provides:

- Direction
- Timestamp
- Symbol

Timestamp is already broker time.

One Telegram signal always corresponds to one M1 candle.

---

## Candle

Find the M1 candle whose open time exactly matches the Telegram timestamp.

The candle is used as the Fibonacci anchor.

---

## Fibonacci

Draw Fibonacci from wick to wick using the signal candle only.

BUY orientation:

- VOID (4.23)
- BO (2.618)
- TP (2.5)
- TP E4-E7 (0.618)
- E3 (0)
- E3.5 (-0.809)
- E4 (-1.618)
- E4.5 (-2.424)
- E5 (-3.23)
- E5.5 (-4.539)
- E6 (-5.848)
- E6.5 (-8.424)
- E7 (-11)
- E7.5 (-13.934)
- E8 (-16.868)
- E8.5 (-22.358)
- E9 (-27.848)
- E9.5 (-36.272)
- E10 (-44.696)

SELL uses the same Fibonacci ratios but the Fibonacci orientation is reversed.

---

## Range Classification

Measure the distance between E3 and E5.

Range < 35,000

Reject signal.

No trading.

---

35,000 ≤ Range ≤ 45,000

Normal range.

Create:

- BUY STOP @ BO
- BUY LIMIT @ E3
- BUY LIMIT @ E4
- BUY LIMIT @ E5

---

Range > 45,000

Wide range.

Create:

- BUY LIMIT @ E5
- BUY LIMIT @ E6
- BUY LIMIT @ E7
- BUY LIMIT @ E8
- BUY LIMIT @ E9
- BUY LIMIT @ E10

---

## Breakout

BUY Trigger

Price breaks BO.

SELL Trigger

Price breaks E4.

When E4 breaks, the original BUY Fibonacci becomes invalid.

Recalculate Fibonacci using the opposite orientation before evaluating SELL entries.

---

## Pending Orders

Orders are created immediately after breakout confirmation.

No delayed order creation.

---

## BUY Workflow

1. Wait for BO breakout.

2. After BO breaks:

   - BUY becomes valid.
   - Pending orders are created according to the current range classification.

3. If price reaches VOID:

   - Signal is completed.

4. If price retraces:

   - Between BO and E3:
     - BUY STOP remains at BO.

   - To E3:
     - Take Profit = TP.

   - To E4:
     - Take Profit = TP E4-E7.

   - To E5 or deeper:
     - Close every BUY position at E3.

---

## SELL Workflow

1. Wait for price to break E4.

2. Reverse the Fibonacci using the same signal candle.

3. Apply the same workflow as BUY using the reversed Fibonacci orientation.

---

## Basket Rules

Defined after the execution phase.

Current milestone focuses on pending order generation.

---

## Manual Monitoring

Version 1.

Trader monitors trades manually.

Automation will be introduced in later phases.