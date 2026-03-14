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
  BarChart,
  Bar
} from "recharts"

export default class extends Controller {
  static targets = ["chart", "fallback"]
  static values = {
    points: Array,
    title: { type: String, default: "Run trend (14d)" },
    chartKind: { type: String, default: "bar" },
    tooltipLabel: { type: String, default: "Day" },
    tooltipCountLabel: { type: String, default: "Runs" },
    animationMode: { type: String, default: "proportional" },
    baseDuration: { type: Number, default: 260 },
    maxExtraDuration: { type: Number, default: 540 }
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

    const points = this.pointsValue || []
    const chartData = points.map((point) => ({
      day: point.day,
      runs: Number(point.count || 0)
    }))

    const reduceMotion = this.prefersReducedMotion()
    const maxValue = Math.max(...chartData.map((point) => point.runs), 1)

    const tooltip = ({ active, payload, label }) => {
      if (!active || !payload || !payload.length) return null

      const value = Number(payload[0]?.value || 0)

      return React.createElement(
        "div",
        { className: "trend-chart__tooltip", role: "tooltip" },
        React.createElement("p", { className: "trend-chart__tooltip-label" }, label),
        React.createElement(
          "p",
          { className: "trend-chart__tooltip-value" },
          React.createElement("span", { className: "trend-chart__tooltip-dot", "aria-hidden": "true" }),
          React.createElement("span", null, this.tooltipCountLabelValue),
          React.createElement("strong", null, value)
        )
      )
    }

    this.root.render(
      React.createElement(
        "div",
        {
          className: "trend-chart__shell",
          role: "img",
          "aria-label": `${this.titleValue}. Last 14 days execution counts shown as bars.`
        },
        React.createElement(
          ResponsiveContainer,
          { width: "100%", height: "100%" },
          React.createElement(
            BarChart,
            { data: chartData, margin: { top: 18, right: 12, left: 6, bottom: 10 }, barCategoryGap: "30%" },
            React.createElement(CartesianGrid, { vertical: false, stroke: "rgba(148, 163, 184, 0.16)" }),
            React.createElement(XAxis, {
              dataKey: "day",
              tickLine: false,
              tickMargin: 10,
              axisLine: false,
              tick: { fill: "#94a3b8", fontSize: 11 }
            }),
            React.createElement(YAxis, {
              allowDecimals: false,
              tickLine: false,
              axisLine: false,
              tick: { fill: "#64748b", fontSize: 11 }
            }),
            React.createElement(Tooltip, {
              cursor: { fill: "rgba(255,255,255,0.04)" },
              content: tooltip,
              isAnimationActive: !reduceMotion
            }),
            React.createElement(Legend, {
              iconType: "circle",
              wrapperStyle: { color: "#94a3b8", fontSize: "12px", paddingTop: "6px" }
            }),
            React.createElement(Bar, {
              dataKey: "runs",
              name: this.tooltipCountLabelValue,
              fill: "#3b82f6",
              radius: [4, 4, 0, 0],
              animationDuration: this.animationDurationFor(maxValue, maxValue, reduceMotion),
              animationBegin: this.animationDelayFor(0, reduceMotion),
              isAnimationActive: !reduceMotion
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

  animationDurationFor(value, maxValue, reduceMotion) {
    if (reduceMotion) return 0
    if (this.animationModeValue !== "proportional") return this.baseDurationValue

    const safeValue = Number(value || 0)
    const ratio = Math.max(0, Math.min(safeValue / maxValue, 1))
    return Math.round(this.baseDurationValue + (this.maxExtraDurationValue * ratio))
  }

  animationDelayFor(dataIndex, reduceMotion) {
    if (reduceMotion) return 0

    return Math.min(18 * Number(dataIndex || 0), 260)
  }

  prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
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
}
