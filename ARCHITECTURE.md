# MT5-AI-EA Architecture

## High-Level Overview

Telegram
    ↓
Python Gateway
    ↓
signal.json
    ↓
MT5 Expert Advisor
    ↓
MetaTrader 5

---

## Python Responsibilities

Receive Telegram messages.

Validate signal.

Write signal.json.

Nothing else.

---

## EA Responsibilities

Read signal.

Find M1 candle.

Plot Fibonacci.

Calculate strategy.

Monitor breakout.

Generate trading plan.

Execute pending orders.

Manage trades.

Export state.

---

## Future Architecture

EA
    ↓
state.json
    ↓
Python
    ↓
Astra

Astra analyses exported state.

EA remains the execution engine.

---

## Module Layout

MT5_AI.mq5

include/

Config

SignalReader

CandleFinder

Fibonacci

ChartDrawer

RangeFilter

BreakoutDetector

TradingPlan

TradeExecutor

TradeManager

Utils

---

## Design Principles

Single Responsibility.

Deterministic behaviour.

No duplicated strategy.

No MT5 logic outside EA.

No strategy logic inside Python.