import { Controller } from "@hotwired/stimulus"
import React from "react"
import { createRoot } from "react-dom/client"
import {
  ResponsiveContainer,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
  LineChart,
  Line,
  Dot
} from "recharts"

export default class extends Controller {
  static targets = ["chart", "fallback"]
  static values = {
    points: Array,
    title: { type: String, default: "PnL trend" },
    tooltipLabel: { type: String, default: "Total PnL Quote" }
  }

  connect() {
    if (!this.hasChartTarget) return

    this.showFallback()

    try {
      this.root = createRoot(this.chartTarget)
      this.renderChart()
      this.verifyRenderAndToggle()
    } catch (_error) {
      this.showFallback()
    }
  }

  disconnect() {
    if (this.root) {
      this.root.unmount()
      this.root = null
    }
  }

  renderChart() {
    if (!this.root) return

    const chartData = (this.pointsValue || []).map((point) => ({
      label: point.label,
      timestamp: point.timestamp,
      totalPnlQuote: Number(point.total_pnl_quote || 0)
    }))

    const reduceMotion = this.prefersReducedMotion()

    const tooltip = ({ active, payload, label }) => {
      if (!active || !payload || !payload.length) return null

      const value = Number(payload[0]?.value || 0).toFixed(2)

      return React.createElement(
        "div",
        { className: "trend-chart__tooltip", role: "tooltip" },
        React.createElement("p", { className: "trend-chart__tooltip-label" }, label),
        React.createElement(
          "p",
          { className: "trend-chart__tooltip-value" },
          React.createElement("span", { className: "trend-chart__tooltip-dot", "aria-hidden": "true" }),
          React.createElement("span", null, this.tooltipLabelValue),
          React.createElement("strong", null, value)
        )
      )
    }

    const activeDot = React.createElement(Dot, {
      r: 5,
      fill: "#60a5fa",
      stroke: "#111827",
      strokeWidth: 2
    })

    this.root.render(
      React.createElement(
        "div",
        {
          className: "trend-chart__shell",
          role: "img",
          "aria-label": `${this.titleValue}. Global total PnL quote over successful runs.`
        },
        React.createElement(
          ResponsiveContainer,
          { width: "100%", height: "100%" },
          React.createElement(
            LineChart,
            { data: chartData, margin: { top: 16, right: 12, left: 6, bottom: 10 } },
            React.createElement(CartesianGrid, { vertical: false, stroke: "rgba(148, 163, 184, 0.16)" }),
            React.createElement(XAxis, {
              dataKey: "label",
              tickLine: false,
              tickMargin: 10,
              axisLine: false,
              tick: { fill: "#94a3b8", fontSize: 11 }
            }),
            React.createElement(YAxis, {
              tickLine: false,
              axisLine: false,
              width: 72,
              tickFormatter: (value) => Number(value).toFixed(0),
              tick: { fill: "#64748b", fontSize: 11 }
            }),
            React.createElement(Tooltip, {
              cursor: { stroke: "rgba(148, 163, 184, 0.28)", strokeWidth: 1 },
              content: tooltip,
              isAnimationActive: !reduceMotion
            }),
            React.createElement(Line, {
              type: "monotone",
              dataKey: "totalPnlQuote",
              name: this.tooltipLabelValue,
              stroke: "#60a5fa",
              strokeWidth: 2,
              dot: false,
              activeDot,
              isAnimationActive: !reduceMotion,
              animationDuration: 420
            })
          )
        )
      )
    )
  }

  showFallback() {
    if (this.hasChartTarget) this.chartTarget.classList.remove("is-ready")
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = false
  }

  showChart() {
    if (this.hasChartTarget) this.chartTarget.classList.add("is-ready")
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = true
  }

  verifyRenderAndToggle(attempt = 0) {
    requestAnimationFrame(() => {
      const rendered = this.hasChartTarget && this.chartTarget.querySelector("svg")

      if (rendered) {
        this.showChart()
        window.dispatchEvent(new Event("resize"))
        return
      }

      if (attempt < 8) {
        this.verifyRenderAndToggle(attempt + 1)
        return
      }

      this.showFallback()
    })
  }

  prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
