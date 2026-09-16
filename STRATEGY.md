# Trading Strategy

## Signal

Telegram provides:

- Direction
- Timestamp
- Symbol

Timestamp is already broker time.

---

## Candle

Find the M1 candle matching the timestamp.

---

## Fibonacci

Plot from wick to wick.

Levels:

BO

E3

E4

VOID (E5)

E6

E7

E8

E9

E10

---

## Range Classification

Measure distance between E3 and E5.

Range < 35,000

Reject signal.

No trading.

---

35,000 ≤ Range ≤ 45,000

Normal range.

Use:

BUY STOP @ BO

BUY LIMIT @ E3

BUY LIMIT @ E4

BUY LIMIT @ E5

---

Range > 45,000

Wide range.

Use:

BUY LIMIT @ E5

BUY LIMIT @ E6

BUY LIMIT @ E7

BUY LIMIT @ E8

BUY LIMIT @ E9

BUY LIMIT @ E10

---

## Breakout

BUY

Break BO.

SELL

Break E4.

SELL requires Fibonacci reversal.

---

## Pending Orders

Orders are created immediately after breakout confirmation.

No delayed order creation.

---

## BUY

Break BO.

↓

Create pending orders.

↓

Monitor fills.

↓

Apply TP rules.

---

## SELL

Mirror BUY logic.

---

## Basket Rules

Defined after execution phase.

Current milestone focuses on pending order generation.

---

## Manual Monitoring

Version 1.

Trader monitors trades manually.

Automation will be introduced in later phases.