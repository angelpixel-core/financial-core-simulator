import { Controller } from "@hotwired/stimulus"
import * as echarts from "echarts"

export default class extends Controller {
  static targets = ["chart", "fallback"]
  static values = {
    points: Array,
    title: { type: String, default: "Run trend (14d)" },
    animationMode: { type: String, default: "proportional" },
    baseDuration: { type: Number, default: 260 },
    maxExtraDuration: { type: Number, default: 540 }
  }

  connect() {
    if (!this.hasChartTarget) return

    try {
      this.chart = echarts.init(this.chartTarget, null, { renderer: "svg" })
      this.renderChart()
      this.chartTarget.classList.add("is-ready")
      if (this.hasFallbackTarget) this.fallbackTarget.hidden = true

      this.resizeObserver = new ResizeObserver(() => this.chart.resize())
      this.resizeObserver.observe(this.chartTarget)
    } catch (_error) {
      this.showFallback()
    }
  }

  disconnect() {
    if (this.resizeObserver) this.resizeObserver.disconnect()
    if (this.chart) this.chart.dispose()
  }

  renderChart() {
    const points = this.pointsValue || []
    const labels = points.map((point) => point.day)
    const values = points.map((point) => Number(point.count || 0))
    const reduceMotion = this.prefersReducedMotion()
    const maxValue = Math.max(...values, 1)

    this.chart.setOption({
      aria: {
        show: true,
        description: `${this.titleValue}. Last 14 days execution counts.`
      },
      grid: {
        left: 24,
        right: 18,
        top: 28,
        bottom: 24,
        containLabel: true
      },
      xAxis: {
        type: "category",
        data: labels,
        boundaryGap: false,
        axisLabel: { color: "#5d6679", fontSize: 11 },
        axisLine: { lineStyle: { color: "#d9e0eb" } },
        axisTick: { show: false }
      },
      yAxis: {
        type: "value",
        minInterval: 1,
        axisLabel: { color: "#5d6679", fontSize: 11 },
        splitLine: { lineStyle: { color: "#e7edf7" } }
      },
      tooltip: {
        trigger: "axis",
        axisPointer: { type: "line" }
      },
      series: [
        {
          type: "line",
          data: values,
          smooth: true,
          showSymbol: false,
          animation: !reduceMotion,
          animationDuration: (dataIndex) => this.animationDurationFor(values[dataIndex], maxValue, reduceMotion),
          animationDurationUpdate: (dataIndex) => this.animationDurationFor(values[dataIndex], maxValue, reduceMotion),
          animationEasing: "cubicOut",
          animationEasingUpdate: "cubicOut",
          lineStyle: { width: 3, color: "#0f766e" },
          areaStyle: {
            color: {
              type: "linear",
              x: 0,
              y: 0,
              x2: 0,
              y2: 1,
              colorStops: [
                { offset: 0, color: "rgba(15, 118, 110, 0.34)" },
                { offset: 1, color: "rgba(15, 118, 110, 0.03)" }
              ]
            }
          }
        }
      ]
    })
  }

  showFallback() {
    if (this.hasChartTarget) this.chartTarget.classList.remove("is-ready")
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = false
  }

  animationDurationFor(value, maxValue, reduceMotion)
  {
    if (reduceMotion) return 0
    if (this.animationModeValue !== "proportional") return this.baseDurationValue

    const safeValue = Number(value || 0)
    const ratio = Math.max(0, Math.min(safeValue / maxValue, 1))
    return Math.round(this.baseDurationValue + (this.maxExtraDurationValue * ratio))
  }

  prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
