import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["items", "total", "template"]

  connect() {
    this.itemIndex = Date.now()
    this.updateTotal()
  }

  scaled(value, places) {
    if (!new RegExp(`^\\d+(?:\\.\\d{0,${places}})?$`).test(value)) return 0n
    const [whole, fraction = ""] = value.split(".")
    return BigInt(whole) * (10n ** BigInt(places)) + BigInt(fraction.padEnd(places, "0"))
  }

  updateTotal() {
    let total = 0n
    this.itemsTarget.querySelectorAll(".line-row:not([hidden])").forEach(row => {
      const quantity = this.scaled(row.querySelector(".item-quantity").value, 3)
      const cents = this.scaled(row.querySelector(".item-rate").value, 2)
      total += (quantity * cents + 500n) / 1000n
    })
    this.totalTarget.textContent = new Intl.NumberFormat("en-CA", {style: "currency", currency: "CAD"}).format(Number(total) / 100)
  }

  add() {
    this.itemsTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll("NEW_ITEM", String(++this.itemIndex)))
    this.itemsTarget.lastElementChild.querySelector("input[type=text]").focus()
  }

  remove(event) {
    const remove = event.target.closest(".remove-item")
    if (!remove) return
    const row = remove.closest(".line-row")
    row.querySelector(".destroy-item").value = "1"
    row.hidden = true
    row.querySelectorAll("input:not([type=hidden])").forEach(input => input.required = false)
    this.updateTotal()
  }

  filter(event) {
    const term = event.target.value.toLowerCase()
    this.element.querySelectorAll(".game-option").forEach(option => { option.hidden = !option.dataset.search.includes(term) })
  }
}
