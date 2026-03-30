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
  BarChart,
  Bar
} from "recharts"

export default class extends Controller {
  static targets = ["activityChart", "volumeChart", "cards", "emptyState", "activityFallback", "volumeFallback"]
  static values = {
    url: String,
    activityTitle: { type: String, default: "Trade activity" },
    volumeTitle: { type: String, default: "Trade volume" },
    activityTooltipLabel: { type: String, default: "Trades" },
    volumeTooltipLabel: { type: String, default: "Volume" }
  }

  connect() {
    this.showLoading()

    if (!this.urlValue) {
      this.showEmptyState()
      return
    }

    this.fetchOverview()
  }

  disconnect() {
    if (this.activityRoot) {
      this.activityRoot.unmount()
      this.activityRoot = null
    }
    if (this.volumeRoot) {
      this.volumeRoot.unmount()
      this.volumeRoot = null
    }
  }

  fetchOverview() {
    fetch(this.urlValue, { headers: { Accept: "application/json" } })
      .then((response) => {
        if (!response.ok) throw new Error("financial_overview_fetch_failed")
        return response.json()
      })
      .then((payload) => {
        const overview = payload?.financial_overview || {}
        const activity = Array.isArray(overview.trade_activity) ? overview.trade_activity : []
        const volume = Array.isArray(overview.trade_volume) ? overview.trade_volume : []

        if (activity.length === 0 && volume.length === 0) {
          this.showEmptyState()
          return
        }

        this.hideEmptyState()

        if (activity.length > 0) {
          this.renderActivityChart(activity)
        } else {
          this.showActivityFallback()
        }

        if (volume.length > 0) {
          this.renderVolumeChart(volume)
        } else {
          this.showVolumeFallback()
        }
      })
      .catch(() => {
        this.showEmptyState()
      })
  }

  renderActivityChart(points) {
    if (!this.hasActivityChartTarget) return

    const chartData = points.map((point) => ({
      label: this.formatTimestamp(point.timestamp),
      tradeCount: Number(point.trade_count || 0)
    }))

    this.activityRoot = this.activityRoot || createRoot(this.activityChartTarget)

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
          React.createElement("span", null, this.activityTooltipLabelValue),
          React.createElement("strong", null, value)
        )
      )
    }

    this.activityRoot.render(
      React.createElement(
        "div",
        {
          className: "trend-chart__shell",
          role: "img",
          "aria-label": `${this.activityTitleValue}. Trade count per day.`
        },
        React.createElement(
          ResponsiveContainer,
          { width: "100%", height: "100%" },
          React.createElement(
            BarChart,
            { data: chartData, margin: { top: 18, right: 12, left: 6, bottom: 10 }, barCategoryGap: "30%" },
            React.createElement(CartesianGrid, { vertical: false, stroke: "rgba(148, 163, 184, 0.16)" }),
            React.createElement(XAxis, {
              dataKey: "label",
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
              content: tooltip
            }),
            React.createElement(Bar, {
              dataKey: "tradeCount",
              name: this.activityTooltipLabelValue,
              fill: "#22c55e",
              radius: [4, 4, 0, 0]
            })
          )
        )
      )
    )

    this.showActivityChart()
  }

  renderVolumeChart(points) {
    if (!this.hasVolumeChartTarget) return

    const chartData = points.map((point) => ({
      label: this.formatTimestamp(point.timestamp),
      volume: Number(point.volume || 0)
    }))

    this.volumeRoot = this.volumeRoot || createRoot(this.volumeChartTarget)

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
          React.createElement("span", null, this.volumeTooltipLabelValue),
          React.createElement("strong", null, value.toFixed(2))
        )
      )
    }

    this.volumeRoot.render(
      React.createElement(
        "div",
        {
          className: "trend-chart__shell",
          role: "img",
          "aria-label": `${this.volumeTitleValue}. Quote volume per day.`
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
              tickFormatter: (value) => Number(value).toFixed(0),
              tick: { fill: "#64748b", fontSize: 11 }
            }),
            React.createElement(Tooltip, {
              cursor: { stroke: "rgba(148, 163, 184, 0.28)", strokeWidth: 1 },
              content: tooltip
            }),
            React.createElement(Line, {
              type: "monotone",
              dataKey: "volume",
              name: this.volumeTooltipLabelValue,
              stroke: "#38bdf8",
              strokeWidth: 2,
              dot: false
            })
          )
        )
      )
    )

    this.showVolumeChart()
  }

  showActivityChart() {
    if (this.hasActivityChartTarget) this.activityChartTarget.classList.add("is-ready")
    if (this.hasActivityFallbackTarget) this.activityFallbackTarget.hidden = true
  }

  showActivityFallback() {
    if (this.activityRoot) {
      this.activityRoot.unmount()
      this.activityRoot = null
    }
    if (this.hasActivityChartTarget) this.activityChartTarget.classList.remove("is-ready")
    if (this.hasActivityFallbackTarget) this.activityFallbackTarget.hidden = false
  }

  showVolumeChart() {
    if (this.hasVolumeChartTarget) this.volumeChartTarget.classList.add("is-ready")
    if (this.hasVolumeFallbackTarget) this.volumeFallbackTarget.hidden = true
  }

  showVolumeFallback() {
    if (this.volumeRoot) {
      this.volumeRoot.unmount()
      this.volumeRoot = null
    }
    if (this.hasVolumeChartTarget) this.volumeChartTarget.classList.remove("is-ready")
    if (this.hasVolumeFallbackTarget) this.volumeFallbackTarget.hidden = false
  }

  showLoading() {
    if (this.hasCardsTarget) this.cardsTarget.hidden = false
    if (this.hasEmptyStateTarget) this.emptyStateTarget.hidden = true
    this.setState("loading")
  }

  showEmptyState() {
    if (this.hasCardsTarget) this.cardsTarget.hidden = true
    if (this.hasEmptyStateTarget) this.emptyStateTarget.hidden = false
    this.setState("empty")
  }

  hideEmptyState() {
    if (this.hasCardsTarget) this.cardsTarget.hidden = false
    if (this.hasEmptyStateTarget) this.emptyStateTarget.hidden = true
    this.setState("ready")
  }

  setState(state) {
    this.element.dataset.financialOverviewState = state
  }

  formatTimestamp(timestamp) {
    if (!timestamp) return ""

    if (/^\d{4}-\d{2}-\d{2}$/.test(timestamp)) {
      return timestamp
    }

    const date = new Date(timestamp)
    if (Number.isNaN(date.getTime())) return ""

    const year = date.getUTCFullYear()
    const month = String(date.getUTCMonth() + 1).padStart(2, "0")
    const day = String(date.getUTCDate()).padStart(2, "0")
    return `${year}-${month}-${day}`
  }
}
