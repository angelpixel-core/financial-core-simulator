import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel",
    "title",
    "source",
    "sourceId",
    "ingestionId",
    "ingestionStatus",
    "uploadId",
    "uploadStatus",
    "createdBy",
    "createdAt",
    "updatedAt",
    "gapStatus",
    "events",
    "sourceLink",
    "ingestionLink",
    "eventLink"
  ]

  open(event) {
    const payload = this.parsePayload(event.currentTarget)
    if (!payload) return

    this.titleTarget.textContent = `${payload.pair} · ${payload.date}`
    this.sourceTarget.textContent = this.composeSource(payload)
    this.sourceIdTarget.textContent = payload.source_id || "-"
    this.ingestionIdTarget.textContent = payload.ingestion_id || "-"
    this.ingestionStatusTarget.textContent = payload.ingestion_status || "-"
    this.uploadIdTarget.textContent = payload.upload_id || "-"
    this.uploadStatusTarget.textContent = payload.upload_status || "-"
    this.createdByTarget.textContent = payload.created_by || "-"
    this.createdAtTarget.textContent = payload.created_at || "-"
    this.updatedAtTarget.textContent = payload.updated_at || "-"
    this.gapStatusTarget.textContent = payload.gap_status || "-"

    this.renderEvents(payload.events || [])
    this.configureLinks(payload)

    this.panelTarget.hidden = false
    requestAnimationFrame(() => this.panelTarget.classList.add("is-open"))
  }

  close() {
    this.panelTarget.classList.remove("is-open")
    window.setTimeout(() => {
      this.panelTarget.hidden = true
    }, 150)
  }

  parsePayload(target) {
    try {
      return JSON.parse(target.dataset.lineagePayload)
    } catch (_error) {
      return null
    }
  }

  composeSource(payload) {
    return [payload.source_label, payload.source].filter(Boolean).join(" · ")
  }

  renderEvents(events) {
    this.eventsTarget.innerHTML = ""

    if (events.length === 0) {
      const emptyItem = document.createElement("li")
      emptyItem.textContent = "-"
      this.eventsTarget.appendChild(emptyItem)
      return
    }

    events.forEach((event) => {
      const item = document.createElement("li")
      item.classList.add("fx-lineage-panel__event")
      const label = document.createElement("span")
      label.textContent = event.event_type
      const meta = document.createElement("span")
      meta.textContent = event.created_at
      item.append(label, meta)
      this.eventsTarget.appendChild(item)
    })
  }

  configureLinks(payload) {
    this.configureLink(this.sourceLinkTarget, payload.links?.source)
    this.configureLink(this.ingestionLinkTarget, payload.links?.ingestion)

    const event = payload.events && payload.events.length > 0 ? payload.events[0] : null
    const eventUrl = event?.id ? `/avo/resources/fx_rate_events/${event.id}` : null
    this.configureLink(this.eventLinkTarget, eventUrl)
  }

  configureLink(element, url) {
    if (url) {
      element.href = url
      element.classList.remove("is-disabled")
      element.removeAttribute("aria-disabled")
    } else {
      element.href = "#"
      element.classList.add("is-disabled")
      element.setAttribute("aria-disabled", "true")
    }
  }
}
