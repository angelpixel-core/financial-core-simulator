---
id: ARCHITECTURE
aliases: []
tags: []
---

# Architecture

Financial Core Simulator (FCS) is a **modular financial processing system** designed around deterministic execution, domain separation, and operational observability.

This document explains **what is actually implemented**, not aspirational architecture.

---

## 1. System Overview

FCS is composed of two main runtime layers:

```txt
lib/fcs        → Core financial engine (pure domain)
apps/admin     → Rails operational workspace (UI + orchestration)
```

## Mental Model

```txt
           ┌──────────────────────────────┐
           │        Admin Workspace       │
           │  (Rails + Avo + Controllers) │
           └──────────────┬───────────────┘
                          │
                          ▼
           ┌──────────────────────────────┐
           │        Application Layer     │
           │   (Runner, Reporting, Flow)  │
           └──────────────┬───────────────┘
                          │
                          ▼
           ┌──────────────────────────────┐
           │        Core Engine           │
           │ (Ledger, Positions, Risk)    │
           └──────────────────────────────┘
```

---

# 2. Core Design Principles

## 2.1 Determinism

All executions are deterministic by design:

- Inputs are normalized into canonical JSON
- Inputs are hashed using SHA-256
- Runs produce identical outputs for identical inputs

```
Same Input → Same Hash → Same Execution → Same Artifacts
```

Key implementation:

- lib/fcs/hashing/canonical_json.rb
- lib/fcs/hashing/sha256.rb
- lib/fcs/application/runner.rb

---

## 2.2 Auditability

Every run is traceable:

- Input hash stored and verified post-execution
- Artifacts persisted (JSON + CSV)
- FX lineage and ingestion events tracked

Key implementation:

- apps/admin/app/domains/runs/app/services/runs/verify_input_hash.rb
- FX lineage via:
  - fx_rate
  - fx_rate_event

---

## 2.3 Modular Monolith (with Boundaries)

The system is a modular monolith enforced via Packwerk:

- Core boundaries: lib/fcs/\*/package.yml
- Admin boundaries: apps/admin/app/domains/\*/package.yml

Packwerk configs:

- lib/packwerk.yml
- apps/admin/packwerk.yml

CI enforces boundary correctness.

---

# 3. Domain Architecture

## 3.1 Core Engine (lib/fcs)

This layer is:

- Pure Ruby
- Stateless execution logic
- Reusable (no Rails dependency)

Main components

```txt
engine/
  ledger_engine.rb
  position.rb
  position_fifo.rb
  valuation_engine.rb
  risk_engine.rb

ingestion/
  parser.rb
  validator.rb
  source_event_* (idempotency, normalization)

reporting/
  json_report.rb
  csv_pnl.rb
  csv_positions.rb

projector/
  read_model_replay.rb
```

---

## 3.2 Application Layer

Coordinates execution:

```txt
lib/fcs/application/
  runner.rb
  report_payload_builder.rb
  report_artifacts_writer.rb
```

Responsibilities:

- orchestrate ingestion → execution → reporting
- ensure determinism constraints
- produce artifacts

---

## 3.3 Admin Domains (apps/admin/app/domains)

Each domain acts as a bounded context (partially enforced).

Main domains:

```txt
runs        → execution orchestration + verification
fx          → rates, ingestion, lineage
dashboard   → KPIs + projections
demo        → dataset flows + sandbox control
auth        → authentication/authorization
artifacts   → run outputs
```

Domains expose APIs/facades:

- Runs::Api
- Admin::Fx::Api

---

# 4. Runtime Flows

---

## 4.1 Run Execution Flow

```txt
1. Input ingestion
2. Validation + normalization
3. Deterministic execution
4. Artifact generation
5. Persistence
6. Verification (hash)
7. Exposure via UI
```

Key files:

- lib/fcs/application/runner.rb
- apps/admin/app/controllers/run_executions_controller.rb
- apps/admin/app/domains/runs/app/services/runs/verify_input_hash.rb

---

## 4.2 FX Ingestion Flow

```txt
1. Admin triggers sync/upload
2. Adapter fetches external data
3. Validator checks payload
4. Mapper converts to internal format
5. Persistence (rates + events)
6. Exposure in history + health
```

Adapters:

- BCRA:
  - .../fx/ingestion/adapters/bcra_adapter.rb
- Binance:
  - .../fx/ingestion/adapters/binance_adapter.rb

Controllers:

- admin/fx/history_controller.rb
- admin/fx/ingestions_controller.rb

```txt
1. Events generated (runs / FX)
2. Stored in DB
3. Queried via snapshots
4. Rendered in UI (health dashboard)
```

Key:

- system_health_controller.rb
- observability_snapshot.rb

---

# 5. Ports and Adapters

## Current State: Partially Implemented

Core defines ports:

```txt
lib/fcs/ports/*
```

Adapters implemented mainly in admin:

```txt
apps/admin/.../fx/ingestion/adapters/*
```

## Reality

- Pattern exists ✔
- Enforcement is partial ❗
- Not all dependencies are inverted yet

---

# 6. Patterns in Use

## Fully Implemented

- Modular Monolith
- Deterministic Execution
- Auditability / Traceability
- Packwerk boundaries
- Structured ingestion pipeline

---

## Partially Implemented

- Domain Driven Design (bounded contexts exist but are coupled)
- Hexagonal Architecture (ports/adapters not fully enforced)
- Event-driven instrumentation (not full event architecture)

---

## Not Yet Implemented

- Multi-tenancy
- External API productization
- Full retry/backoff standardization
- Distributed event system

---

# 7. Observability Design

Built-in observability includes:

- Run success/failure metrics
- FX ingestion errors
- Event stream
- Pagination of operational data

Key UI:

```txt
/admin/system_health
```

This is application-level observability, not full SRE infra.

---

# 8. Trade-offs

- [ ]

## Strengths

- Strong domain modeling in core engine
- Determinism is real (not simulated)
- FX ingestion pipeline is extensible
- Observability is integrated into product
- Admin UI is operationally useful

---

## Weaknesses

- Partial enforcement of hexagonal boundaries
- Domain coupling in admin layer
- Demo-related logic mixed with core flows
- Some legacy controllers overlap
- Not multi-tenant

---

# 9. Known Limitations

- Not designed for real-time trading
- Not horizontally scalable yet
- Async processing is basic (not queue-heavy infra)
- Observability is not production-grade SRE stack
- FX normalization assumes simplified models (e.g., USDT ≈ USD)

---

# 10. Positioning

This system should be understood as:

> A deterministic financial processing workspace and engine demo

Not:

- A production exchange
- A multi-tenant SaaS
- A real-time trading system

---

# 11. Evolution Path

Possible next steps:

- strict ports/adapters enforcement
- multi-tenant domain model
- external API layer
- event-driven pipeline
- SRE-grade observability (metrics, tracing)
- infra-as-code integration

---

# 12. Key Files Index

## Core

- lib/fcs/application/runner.rb
- lib/fcs/engine/ledger_engine.rb
- lib/fcs/ingestion/parser.rb
- lib/fcs/reporting/json_report.rb

## Admin

- apps/admin/app/controllers/admin/overview_controller.rb
- apps/admin/app/controllers/admin/system_health_controller.rb
- apps/admin/app/controllers/admin/fx/history_controller.rb

## FX

- .../fx/ingestion/adapters/bcra_adapter.rb
- .../fx/ingestion/adapters/binance_adapter.rb

## Runs

- run_execution_job.rb
- verify_input_hash.rb

---

# Final Note

The value of this system is not just in its features, but in:

- determinism guarantees
- auditability
- domain modeling
- architectural intent with real implementation

This is a technical system designed to be understood, extended, and challenged.
