import { Controller } from "@hotwired/stimulus"
import React from "react"
import { createRoot } from "react-dom/client"
import {
  ResponsiveContainer,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
  Legend,
  LineChart,
  Line,
  Dot
} from "recharts"

export default class extends Controller {
  static targets = ["chart", "fallback", "toggle"]
  static values = {
    points: Array,
    series: Array,
    title: { type: String, default: "Market (USD)" },
    tooltipLabel: { type: String, default: "USD value" }
  }

  connect() {
    if (!this.hasChartTarget) return

    this.hiddenSeries = new Set()

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
      ...point,
      label: point.label,
      timestamp: point.timestamp
    }))
    const activeSeries = (this.seriesValue || []).filter((series) => !this.hiddenSeries.has(series.key))

    if (activeSeries.length === 0) {
      this.showFallback()
      return
    }

    const reduceMotion = this.prefersReducedMotion()

    const tooltip = ({ active, payload, label }) => {
      if (!active || !payload || !payload.length) return null

      return React.createElement(
        "div",
        { className: "trend-chart__tooltip", role: "tooltip" },
        React.createElement("p", { className: "trend-chart__tooltip-label" }, label),
        ...payload.map((entry) =>
          React.createElement(
            "p",
            { className: "trend-chart__tooltip-value", key: entry.dataKey },
            React.createElement("span", { className: "trend-chart__tooltip-dot", "aria-hidden": "true", style: { background: entry.color } }),
            React.createElement("span", null, entry.name),
            React.createElement("strong", null, entry.value == null ? "N/A" : Number(entry.value).toFixed(6))
          )
        )
      )
    }

    this.root.render(
      React.createElement(
        "div",
        {
          className: "trend-chart__shell",
          role: "img",
          "aria-label": `${this.titleValue}. USD normalized market trend.`
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
              width: 76,
              tickFormatter: (value) => Number(value).toFixed(2),
              tick: { fill: "#64748b", fontSize: 11 }
            }),
            React.createElement(Tooltip, {
              cursor: { stroke: "rgba(148, 163, 184, 0.28)", strokeWidth: 1 },
              content: tooltip,
              isAnimationActive: !reduceMotion
            }),
            React.createElement(Legend, {
              iconType: "circle",
              wrapperStyle: { color: "#94a3b8", fontSize: "12px", paddingTop: "6px" }
            }),
            ...activeSeries.map((series) => {
              const activeDot = React.createElement(Dot, {
                r: 4,
                fill: series.color,
                stroke: "#0f172a",
                strokeWidth: 2
              })

              return React.createElement(Line, {
                key: series.key,
                type: "monotone",
                dataKey: series.key,
                name: series.label,
                stroke: series.color,
                strokeWidth: 2,
                dot: false,
                activeDot,
                connectNulls: false,
                isAnimationActive: !reduceMotion,
                animationDuration: 420
              })
            })
          )
        )
      )
    )

    this.updateToggleState()
  }

  toggleSeries(event) {
    const key = event.currentTarget?.dataset?.seriesKey
    if (!key) return

    if (this.hiddenSeries.has(key)) {
      this.hiddenSeries.delete(key)
    } else {
      this.hiddenSeries.add(key)
    }

    this.renderChart()
    this.verifyRenderAndToggle()
  }

  showFallback() {
    if (this.hasChartTarget) this.chartTarget.classList.remove("is-ready")
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = false
  }

  showChart() {
    if (this.hasChartTarget) this.chartTarget.classList.add("is-ready")
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = true
  }

  updateToggleState() {
    if (!this.hasToggleTarget) return

    this.toggleTargets.forEach((button) => {
      const key = button.dataset.seriesKey
      const isActive = !this.hiddenSeries.has(key)
      button.classList.toggle("is-active", isActive)
      button.setAttribute("aria-pressed", isActive ? "true" : "false")
    })
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
