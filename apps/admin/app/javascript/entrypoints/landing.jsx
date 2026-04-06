import React from "react"
import { createRoot } from "react-dom/client"

const rootElement = document.getElementById("landing-react-root")

if (rootElement) {
  const demoPath = rootElement.dataset.demoPath || "/admin/login"
  const sourceUrl = rootElement.dataset.sourceUrl || "https://github.com/angelpixel-core/financial-core-simulator"
  const root = createRoot(rootElement)

  root.render(
    <Landing
      demoPath={demoPath}
      sourceUrl={sourceUrl}
    />
  )

  const fallback = document.querySelector("[data-landing-fallback]")
  if (fallback) {
    fallback.setAttribute("hidden", "true")
  }
}

function Landing({ demoPath, sourceUrl }) {
  const navItems = [
    { label: "Why it exists", href: "#why" },
    { label: "How it works", href: "#how" },
    { label: "Features", href: "#features" },
    { label: "FAQ", href: "#faq" },
  ]

  const featureItems = [
    "Deterministic execution engine",
    "Partial failure handling",
    "FX normalization across markets",
    "Multi-account PnL computation",
    "Run traceability and audit logs",
    "CLI, API, and admin workspace",
  ]

  const steps = [
    {
      title: "Ingest your data",
      body: "Upload trades and FX rates through CLI, API, or the web workspace.",
    },
    {
      title: "Validate and normalize",
      body: "Detect inconsistencies, standardize formats, and prepare a trustworthy execution payload.",
    },
    {
      title: "Execute deterministically",
      body: "Generate reproducible financial outputs with traceable runs, artifacts, and projections.",
    },
  ]

  const faqs = [
    {
      q: "What does deterministic mean here?",
      a: "The same validated input always produces the same output. That makes runs reproducible, debuggable, and auditable.",
    },
    {
      q: "What happens if a dataset contains errors?",
      a: "Invalid rows are isolated and reported so you can keep visibility into failures without losing operational context.",
    },
    {
      q: "Is this only for trading teams?",
      a: "No. It is useful anywhere financial data must be validated before it reaches dashboards, reports, or operational decisions.",
    },
    {
      q: "Can it integrate with existing systems?",
      a: "Yes. The platform is designed around CLI, API, and workspace-driven ingestion so it can fit into real workflows.",
    },
  ]

  const architecture = [
    { title: "0. Input Interfaces", body: "CLI - Web UI - API" },
    { title: "1. Ingestion", body: "Parser - Preview" },
    { title: "2. Validation + Normalization", body: "Validation Engine - Normalization - Hash" },
    { title: "3. Validation Result", body: "Valid / invalid outcomes" },
    { title: "4. Validation Events", body: "Event stream" },
    { title: "5. Execution", body: "Execution engine - financial projection" },
    { title: "6. Storage", body: "Data store - run storage - system health" },
    { title: "7. Workspace", body: "Admin + operator read models" },
  ]

  return (
    <div className="landing">
      <div className="landing__background" aria-hidden="true">
        <span className="landing__orb landing__orb--one" />
        <span className="landing__orb landing__orb--two" />
        <span className="landing__orb landing__orb--three" />
      </div>

      <header className="landing__header">
        <div className="landing__header-inner">
          <a className="landing__brand" href="#top">
            <span className="landing__brand-mark">DFE</span>
            <span className="landing__brand-copy">
              <span className="landing__brand-title">Deterministic Financial Engine</span>
              <span className="landing__brand-subtitle">Audit-ready financial processing</span>
            </span>
          </a>

          <nav className="landing__nav" aria-label="Landing sections">
            {navItems.map((item) => (
              <a key={item.label} href={item.href}>
                {item.label}
              </a>
            ))}
          </nav>

          <div className="landing__header-actions">
            <a className="landing__primary-cta" href={demoPath}>View Demo</a>
          </div>
        </div>
      </header>

      <main id="top" className="landing__main">
        <section className="landing__hero">
          <div>
            <div className="landing__eyebrow">
              <span className="landing__eyebrow-dot" />
              Deterministic - Event-Driven - Audit-Ready
            </div>
            <h1 className="landing__title">
              Deterministic Financial Processing.
              <span>Always the same input. Always the same output.</span>
            </h1>
            <p className="landing__subtitle">
              Validate, execute, and audit financial data pipelines with reproducible results across trades, FX, and PnL.
            </p>

            <div className="landing__hero-actions">
              <a id="demo" className="landing__primary-cta" href={demoPath}>View Demo</a>
              <a className="landing__secondary-cta" href="#architecture">Explore Architecture</a>
            </div>

            <div className="landing__stats">
              <div className="landing__stat">
                <p className="landing__stat-title">Trades + FX</p>
                <p className="landing__stat-body">Multi-market ingestion</p>
              </div>
              <div className="landing__stat">
                <p className="landing__stat-title">Deterministic runs</p>
                <p className="landing__stat-body">Reproducible financial outputs</p>
              </div>
              <div className="landing__stat">
                <p className="landing__stat-title">Traceability</p>
                <p className="landing__stat-body">Artifacts and run history</p>
              </div>
            </div>
          </div>

          <div className="landing__hero-card">
            <div className="landing__hero-card-header">
              <div>
                <p className="landing__hero-card-eyebrow">Architecture snapshot</p>
                <p className="landing__hero-card-title">Raw inputs - trusted financial state</p>
              </div>
              <span className="landing__badge">Live concept</span>
            </div>

            <div className="landing__pipeline">
              {[
                { title: "Raw Data", body: "Excel - API - CLI" },
                { title: "Validation", body: "Rules + normalization" },
                { title: "Execution", body: "Deterministic engine" },
                { title: "Insight", body: "PnL - trades - trace" },
              ].map((item, index) => (
                <div className="landing__pipeline-step" key={item.title}>
                  <span className="landing__badge">{index + 1}</span>
                  <h3>{item.title}</h3>
                  <p>{item.body}</p>
                </div>
              ))}
            </div>

            <div className="landing__metrics">
              <div className="landing__metric">
                <p className="landing__metric-label">Consistency</p>
                <p className="landing__metric-value">Same input - same output</p>
              </div>
              <div className="landing__metric">
                <p className="landing__metric-label">Failure model</p>
                <p className="landing__metric-value">Partial failure aware</p>
              </div>
              <div className="landing__metric">
                <p className="landing__metric-label">Observability</p>
                <p className="landing__metric-value">Runs, artifacts, health</p>
              </div>
            </div>
          </div>
        </section>

        <section id="why" className="landing__section">
          <div className="landing__section-header">
            <p className="landing__section-eyebrow">Why it exists</p>
            <h2 className="landing__section-title">Financial systems are hard to trust. We make them reproducible.</h2>
          </div>
          <div className="landing__why-grid">
            <div className="landing__panel">
              <p>Raw datasets often travel through fragile workflows before they reach reports, dashboards, and operational decisions.</p>
              <p>
                Deterministic Financial Engine validates, normalizes, and executes financial event streams into reproducible outputs.
                That means every run can be audited, replayed, and trusted.
              </p>
            </div>
          </div>
        </section>

        <section id="how" className="landing__section">
          <div className="landing__section-header">
            <p className="landing__section-eyebrow">How it works</p>
            <h2 className="landing__section-title">A single pipeline from ingestion to financial insight.</h2>
          </div>
          <div className="landing__how-grid">
            {steps.map((step, index) => (
              <div className="landing__how-step" key={step.title}>
                <div className="landing__how-icon">{index + 1}</div>
                <h3>{step.title}</h3>
                <p>{step.body}</p>
              </div>
            ))}
          </div>
        </section>

        <section id="features" className="landing__section">
          <div className="landing__section-header">
            <p className="landing__section-eyebrow">Capabilities</p>
            <h2 className="landing__section-title">Built for deterministic financial workflows.</h2>
          </div>
          <div className="landing__features-grid">
            {featureItems.map((feature) => (
              <div className="landing__feature" key={feature}>
                <div className="landing__feature-bar" />
                <p>{feature}</p>
              </div>
            ))}
          </div>
        </section>

        <section id="architecture" className="landing__section">
          <div className="landing__section-header">
            <p className="landing__section-eyebrow">Architecture</p>
            <h2 className="landing__section-title">From raw trades to audit-ready financial state.</h2>
          </div>
          <div className="landing__architecture-grid">
            <div className="landing__architecture-list">
              {architecture.map((item) => (
                <div className="landing__architecture-item" key={item.title}>
                  <span>{item.title}</span>
                  <p>{item.body}</p>
                </div>
              ))}
            </div>
            <div className="landing__architecture-panel">
              <p className="landing__section-eyebrow">Why this matters</p>
              <h3 className="landing__section-title">A deterministic pipeline that turns untrusted financial data into reproducible outcomes.</h3>
              <p>
                Every dataset goes through parsing, validation, normalization, hashing, execution, storage, and read models before it
                reaches dashboards and operational workflows.
              </p>
              <div className="landing__stat-grid">
                <div className="landing__stat-card">
                  <p className="landing__section-eyebrow">Execution model</p>
                  <p>Deterministic</p>
                </div>
                <div className="landing__stat-card">
                  <p className="landing__section-eyebrow">Failure strategy</p>
                  <p>Partial failure aware</p>
                </div>
                <div className="landing__stat-card">
                  <p className="landing__section-eyebrow">Interfaces</p>
                  <p>CLI - API - Workspace</p>
                </div>
                <div className="landing__stat-card">
                  <p className="landing__section-eyebrow">Outputs</p>
                  <p>PnL - Trades - Traceability</p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section id="faq" className="landing__section">
          <div className="landing__section-header landing__section-header--center">
            <p className="landing__section-eyebrow">FAQ</p>
            <h2 className="landing__section-title">Questions teams ask before they trust financial outputs.</h2>
            <p className="landing__section-subtitle">Frequently asked questions</p>
          </div>
          <div className="landing__faq-stack">
            {faqs.map((item) => (
              <details className="landing__faq-card" key={item.q}>
                <summary>
                  <span className="landing__faq-question">{item.q}</span>
                </summary>
                <p className="landing__faq-answer">{item.a}</p>
              </details>
            ))}
          </div>
        </section>
      </main>

      <footer className="landing__footer">
        <div className="landing__footer-inner">
          <div>
            <p className="landing__footer-title">Deterministic Financial Engine</p>
            <p>
              Built to validate, execute, and audit financial event streams with reproducible outcomes across operational workflows.
            </p>
          </div>
          <div>
            <p className="landing__footer-title">Sections</p>
            <div className="landing__footer-links">
              {navItems.map((item) => (
                <a key={item.label} href={item.href}>{item.label}</a>
              ))}
            </div>
          </div>
          <div>
            <p className="landing__footer-title">Project</p>
            <div className="landing__footer-links">
              <a href="#architecture">Architecture</a>
              <a href={sourceUrl}>View source</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}
