# Architecture Decisions

## Decision 001

Architecture:

Hybrid

Python + EA

Reason:

Python is better suited for Telegram integration.

EA is better suited for MetaTrader trading logic.

---

## Decision 002

Signal Communication

signal.json

Reason:

Simple.

Reliable.

Easy to debug.

May be replaced later without affecting EA modules.

---

## Decision 003

Trading Engine

All strategy logic belongs inside the EA.

Python never performs strategy calculations.

---

## Decision 004

Manual Monitoring

Version 1 uses manual trade supervision.

Automation will be added incrementally after strategy validation.

---

## Decision 005

Architecture Principle

EA owns the market.

Python owns communication.

Astra owns intelligence.