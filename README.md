# Financial Core Simulator

[![CI](https://github.com/angelpixel-core/financial-core-simulator/actions/workflows/ci.yml/badge.svg)](https://github.com/angelpixel-core/financial-core-simulator/actions/workflows/ci.yml)
[![Mutation Tests](https://github.com/angelpixel-core/financial-core-simulator/actions/workflows/mutation-nightly.yml/badge.svg)](https://github.com/angelpixel-core/financial-core-simulator/actions/workflows/mutation-nightly.yml)
![Ruby](https://img.shields.io/badge/ruby-3.4%2B-red)
![Code Style](https://img.shields.io/badge/code%20style-standardrb-brightgreen)
![License](https://img.shields.io/badge/license-Apache%202.0-blue)

# Financial Core Simulator

> Deterministic financial processing engine with ingestion, FX enrichment, reproducible execution, and operational observability.

---

## 🚀 What is this?

Financial Core Simulator (FCS) is a **modular financial processing system** designed to simulate, validate, and analyze financial event streams with **deterministic execution and full auditability**.

It combines:

- A **core engine** (`lib/fcs`) for deterministic financial computation
- A **Rails operational workspace** (`apps/admin`) for ingestion, FX sourcing, dashboards, and observability

👉 This is not a toy project.
👉 It is a **portfolio-grade system demonstrating real architecture and production-oriented patterns**.

---

## ✨ Key Capabilities

### 1. Deterministic Financial Execution

- Canonical JSON normalization + SHA256 hashing
- Reproducible runs for identical inputs
- Post-run verification of input integrity

```txt
Same input → Same output → Same hash → Same artifacts
```

---

## 2. Ingestion Pipeline (Robust + Fault-Tolerant)

- File upload with preview
- Contract validation (schema, trades, timeline)
- Partial failure handling (runs can execute with known errors)
- Idempotency guards for source events

---

## 3. FX Multi-Source Enrichment

Supports:

- 🇦🇷 BCRA (fiat rates)
- ₿ Binance (crypto rates)
- 📄 Manual uploads (Excel)

Includes:

- Mapping + validation pipelines
- Lineage tracking
- Historical queries
- Event visibility

---

## 4. Financial Engine (Core Domain)

- Position tracking (FIFO / AVG)
- PnL computation
- Risk checks
- Valuation against FX snapshots

---

## 5. Reporting & Artifacts

- JSON reports
- CSV exports (positions, pnl)
- Deterministic artifact generation
- Replay capabilities

---

## 6. Operational Workspace (Admin UI)

- Overview dashboard (KPIs, trends, status mix)
- Dataset preview + validation errors
- FX sourcing & history
- System health + event stream
- Backoffice via Avo

---

## 7. Observability (Built-in)

- Run success/failure tracking
- FX ingestion failures
- Event stream with pagination
- Operational metrics

---

# 🧠 Architecture

FCS follows a modular monolith architecture with strong domain separation.

```
lib/fcs        → Core engine (pure domain)
apps/admin     → Operational workspace (Rails)
```

Patterns used

- Domain Driven Design (partial but real)
- Hexagonal Architecture (ports/adapters)
- Packwerk boundaries
- Deterministic computation
- Event instrumentation
- Auditability + lineage

📄 See full architecture:
👉 [ARCHITECTURE](docs/ARCHITECTURE.md)

---

# ⚙️ Quickstart

```
bundle install
bin/rails db:prepare

BUNDLE_GEMFILE=apps/admin/Gemfile \
bundle exec rails runner apps/admin/script/seed_admin.rb --type local-demo

bin/rails server
```

Open:

- Landing → http://localhost:3000
- Admin → http://localhost:3000/admin

---

# 🎬 Demo Flow (5–10 min)

![demo](./docs/demo.gif)

1. Upload dataset → preview + validation
2. Execute run → deterministic outputs
3. Explore dashboards → KPIs + trends
4. Sync FX rates → BCRA / Binance
5. Inspect system health → events + failures
6. Explore backoffice (Avo)

📄 Full runbook:
👉 docs/DEMO_RUNBOOK.md￼

---

# 🧪 Engineering Quality

- RSpec test suite
- Mutation testing (Mutant)
- Packwerk boundary enforcement
- Brakeman (security)
- Bundler Audit
- RubyCritic
- CI pipelines (multi-layer)

---

# ⚠️ Current Scope (Honest Positioning)

This project is:

✅ A high-fidelity financial processing demo
✅ A portfolio-level architecture showcase
✅ A deterministic simulation engine

This project is NOT (yet):

❌ A production SaaS
❌ Multi-tenant
❌ Real-time trading system
❌ Fully SRE-hardened platform

---

# 🧭 Why this project matters

Most demos fake complexity.

This one demonstrates:

- deterministic computation
- reproducibility guarantees
- ingestion correctness
- FX integration patterns
- operational observability
- architectural discipline

👉 The value is not just features — it’s how they are built.

---

# 🔗 Repository Structure

```
lib/fcs/
  → core financial engine

apps/admin/
  → UI + orchestration + ingestion + FX + observability
```

---

# 📈 Future Directions

- Multi-tenancy
- API-first exposure
- stronger ports/adapters isolation
- real event-driven pipelines
- SRE-level observability

---

# 👤 Author

Angel Pixel
Senior Fullstack Engineer (Ruby / TS / Fintech / Web3)

---

📜 License

MIT
