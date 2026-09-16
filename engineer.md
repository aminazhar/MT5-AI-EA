# MT5-AI-EA Engineering Guide

## Mission

Build a clean, deterministic, maintainable Expert Advisor for MetaTrader 5.

This project prioritizes correctness over speed.

Never over-engineer.

---

# Architecture Principles

Python owns Telegram.

EA owns trading.

Future Astra owns intelligence.

---

# Development Rules

1. Read all project documentation before making changes.

Required reading:

- engineer.md
- ARCHITECTURE.md
- STRATEGY.md
- ROADMAP.md
- DECISIONS.md

---

2. Never write code before explaining:

- Files to create
- Files to modify
- Responsibilities
- Data flow

Wait for approval.

---

3. One feature per branch.

Example:

feature/ea-foundation

feature/range-filter

feature/breakout

---

4. One feature = One Pull Request.

---

5. Never modify unrelated files.

---

6. Every feature must include tests where practical.

---

7. Keep modules small.

One module should own one responsibility.

---

8. Never duplicate business logic.

---

9. Prefer composition over duplication.

---

10. Always explain architectural trade-offs.

Do not silently change architecture.

---

# Coding Style

- Use descriptive names.
- Avoid magic numbers.
- Use constants.
- Prefer enums.
- Keep functions short.
- No unnecessary abstraction.

---

# Responsibilities

Python:

- Telegram
- Signal parsing
- Signal export

EA:

- Candle lookup
- Fibonacci
- Range
- Breakout
- Pending orders
- Trade management

---

# Out of Scope

- AI optimization
- Dashboard
- Cloud deployment
- Multi-strategy
- Performance optimization

These belong to future milestones.


## Development Principle

Do not implement multiple strategy features in a single sprint.

Each sprint should introduce only one new responsibility.

Every sprint must compile successfully before moving to the next.

## Dependencies

Prefer stable, well-maintained libraries over custom implementations when they reduce maintenance cost.

Avoid reinventing common infrastructure such as JSON parsing unless there is a clear project-specific reason.