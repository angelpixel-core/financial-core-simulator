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

## Reproducible Bootstrap (Story 1.1)

Prerequisites:

- Ruby 3.3+
- Bundler 2.5+

Bootstrap and first canonical run:

```bash
bundle install
bin/fcs run --input lib/fcs/fixtures/demo_input.json --output-dir output --verbose
```

Expected canonical artifacts:

- `output/result.json`
- `output/positions.csv`
- `output/pnl.csv`

Determinism check (same input + same config -> identical artifacts):

```bash
bin/fcs run --input lib/fcs/fixtures/demo_input.json --output-dir output/run1
bin/fcs run --input lib/fcs/fixtures/demo_input.json --output-dir output/run2
shasum -a 256 output/run1/result.json output/run2/result.json output/run1/positions.csv output/run2/positions.csv output/run1/pnl.csv output/run2/pnl.csv
```

Error-path sanity checks:

```bash
# Missing input (deterministic exit code 2)
bin/fcs run

# Invalid input payload (deterministic diagnostic JSON)
mkdir -p tmp
printf '{ invalid-json\n' > tmp/bad.json
bin/fcs run --input tmp/bad.json --output-dir output
```
