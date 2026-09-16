# MT5-AI-EA Coding Conventions

## Purpose

This document defines the coding standards and architectural conventions for the MT5-AI-EA project.

These conventions are mandatory for every implementation.

When this document conflicts with a coding preference, this document takes precedence.

---

# General Principles

- Keep every sprint focused on one responsibility.
- Prefer simple solutions over clever solutions.
- Build reusable modules.
- Avoid premature optimization.
- Avoid unnecessary abstractions.

---

# Architecture

Every module should have a single responsibility.

Examples:

SignalReader
- Reads and validates signals.
- Does not know about candles.
- Does not know about trading.

CandleFinder
- Finds candles.
- Does not know about Fibonacci.

Fibonacci
- Calculates levels.
- Does not draw charts.

ChartDrawer
- Draws objects.
- Does not calculate Fibonacci.

TradePlanner
- Produces trading decisions.
- Does not execute trades.

TradeExecutor
- Executes trades.
- Does not decide trades.

---

# Programming Style

Prefer:

- free functions
- structs
- enums

Avoid classes unless there is a clear long-term need.

Prefer:

```cpp
bool SignalReader_Read(...)
```

instead of

```cpp
class SignalReader
```

---

# State

Avoid global mutable state.

Every module should receive input and return output.

Example:

Signal

↓

Candle

↓

FibonacciLevels

↓

TradeDecision

---

# Data Models

Use strongly typed structures.

Avoid passing raw strings between modules.

Prefer:

```cpp
SignalDirection
```

instead of

```cpp
string direction
```

---

# Configuration

Configuration belongs in:

Config.mqh

Examples:

- filenames
- timer interval
- user configurable inputs

---

# Constants

Domain constants belong in:

Constants.mqh

Examples:

- Fibonacci ratios
- enum values
- fixed numeric constants

---

# Helpers

Generic helper functions belong in:

Utils.mqh

Do not place business logic inside Utils.

---

# Error Handling

Return bool for recoverable failures.

Output parameters contain results.

Example:

```cpp
bool CandleFinder_FindM1(..., Candle &candle)
```

Never terminate the EA because of missing input files.

---

# Logging

Only orchestration layers should print logs.

Business modules should not log.

Example:

MT5_AI.mq5

✓ Print

SignalReader

✗ Print

---

# Dependencies

Higher level modules may depend on lower level modules.

Lower level modules must never depend on higher level modules.

Allowed:

SignalReader

↓

CandleFinder

↓

Fibonacci

↓

ChartDrawer

↓

TradePlanner

↓

TradeExecutor

Forbidden:

TradeExecutor

↓

SignalReader

---

# Definition of Done

A sprint is complete only when:

- source code is reviewed
- project compiles
- no warnings
- commit created
- pushed
- PR reviewed
- merged

---

# AI Instructions

AI agents must:

- read engineer.md first
- read this file before coding
- produce an implementation plan
- wait for approval
- modify only approved files
- output complete files
- never auto commit
- never auto merge

---

# Scope Control

Do not implement future roadmap items.

Do not add features outside the approved sprint.

When in doubt:

STOP

and ask for approval.