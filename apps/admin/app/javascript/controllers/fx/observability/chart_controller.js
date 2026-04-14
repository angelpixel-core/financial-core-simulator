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
    series: Array,
    title: { type: String, default: "FX observability" },
    xKey: { type: String, default: "label" },
    tooltipLabel: { type: String, default: "Label" },
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

    const points = Array.isArray(this.pointsValue) ? this.pointsValue : []
    const series = Array.isArray(this.seriesValue) ? this.seriesValue : []

    if (points.length === 0 || series.length === 0) {
      this.showFallback()
      return
    }

    const chartData = points.map((point) => ({
      ...point,
      [this.xKeyValue]: point[this.xKeyValue] || "-"
    }))

    const reduceMotion = this.prefersReducedMotion()
    const maxValue = Math.max(
      ...chartData.flatMap((point) => series.map((entry) => Number(point[entry.key] || 0))),
      1
    )

    const tooltip = ({ active, payload, label }) => {
      if (!active || !payload || !payload.length) return null

      return React.createElement(
        "div",
        { className: "trend-chart__tooltip", role: "tooltip" },
        React.createElement(
          "p",
          { className: "trend-chart__tooltip-label" },
          `${this.tooltipLabelValue}: ${label}`
        ),
        ...payload.map((entry) =>
          React.createElement(
            "p",
            { className: "trend-chart__tooltip-value", key: entry.dataKey },
            React.createElement("span", { className: "trend-chart__tooltip-dot", "aria-hidden": "true" }),
            React.createElement("span", null, entry.name),
            React.createElement("strong", null, Number(entry.value || 0))
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
          "aria-label": `${this.titleValue}. Bar chart.`
        },
        React.createElement(
          ResponsiveContainer,
          { width: "100%", height: "100%" },
          React.createElement(
            BarChart,
            { data: chartData, margin: { top: 18, right: 12, left: 6, bottom: 10 }, barCategoryGap: "30%" },
            React.createElement(CartesianGrid, { vertical: false, stroke: "rgba(148, 163, 184, 0.16)" }),
            React.createElement(XAxis, {
              dataKey: this.xKeyValue,
              tickLine: false,
              tickMargin: 10,
              axisLine: false,
              interval: 0,
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
            ...series.map((entry, index) =>
              React.createElement(Bar, {
                key: entry.key,
                dataKey: entry.key,
                name: entry.label,
                fill: entry.color || "#3b82f6",
                radius: [4, 4, 0, 0],
                animationDuration: this.animationDurationFor(maxValue, maxValue, reduceMotion),
                animationBegin: this.animationDelayFor(index, reduceMotion),
                isAnimationActive: !reduceMotion
              })
            )
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
}
