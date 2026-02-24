# Financial Core Simulator

Financial Core Simulator is a deterministic trading infrastructure demo that models the core components of a modern exchange backend:

- Limit order book (price-time priority)
- Matching engine (deterministic execution)
- Append-only ledger (audit-friendly state transitions)
- Snapshot export (JSON schema)
- Market visualization UI (depth + trade tape)

The project is designed as a technical portfolio piece to demonstrate production-grade architectural patterns used in trading systems, without implementing a real-money exchange.

## Goals

- Model exchange-grade domain primitives (Order, Trade, Book, Money)
- Separate domain from infrastructure via clean architecture
- Ensure deterministic replayability
- Provide auditability via append-only ledger
- Enable visualization of market depth and trade flow
- Keep the core engine framework-agnostic

This repository represents the public demo track.
The engine is intentionally simplified and deterministic.
