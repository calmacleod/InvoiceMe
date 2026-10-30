class InvoiceDraft < ApplicationRecord
  FIELDS = %w[number number_suffix recipient description contact recipient_address issued_on due_on public_notes private_notes].freeze
  belongs_to :user
  belongs_to :season
  belongs_to :invoice, optional: true
  scope :open_work, -> { left_joins(:invoice).where(invoices: { finalized_at: nil }).order(updated_at: :desc, id: :desc) }
  scope :summaries, -> { select(:id, :title, :updated_at, :invoice_id, :season_id, :lock_version, :client_key) }
  validates :client_key, presence: true, length: { maximum: 100 }
  validates :client_key, uniqueness: { scope: :user_id }
  validate :valid_workbench
  before_validation :set_title

  def metadata
    as_json(only: %i[id title updated_at invoice_id season_id lock_version client_key])
  end

  def invoice_data
    attrs = data.deep_dup
    if attrs.key?("contact")
      attrs = attrs.except("contact").reverse_merge("contacts" => InvoiceContacts.from_legacy(data["contact"]))
    end
    if attrs.key?("number") && (!invoice || invoice.number_prefix)
      number = attrs.delete("number")
      attrs["number_suffix"] ||= InvoiceNumbering.suffix(number, season.year)
    end
    attrs
  end

  private
  def set_title
    return unless data.is_a?(Hash)
    parts = data.present? ? [ data["number_suffix"].presence || data["number"], data["recipient"] ] : [ invoice&.number, invoice&.recipient ]
    self.title = parts.filter_map(&:presence).join(" · ").presence || "Untitled draft"
    self.title = title.truncate(180)
  end

  def valid_workbench
    errors.add(:invoice, "belongs to a different year") if invoice && invoice.season_id != season_id
    errors.add(:invoice, "is finalized") if invoice&.finalized_at
    errors.add(:invoice, "is being exported") if invoice && !invoice.finalized_at && invoice.exporting?
    unless data.is_a?(Hash) && data.to_json.bytesize <= 512_000 &&
        (data.keys - FIELDS - %w[contacts game_ids line_items_attributes]).empty? &&
        FIELDS.all? { |field| !data.key?(field) || data[field].is_a?(String) } &&
        (!data.key?("contacts") || InvoiceContacts.valid_format?(data["contacts"])) &&
        (!data.key?("game_ids") || data["game_ids"].is_a?(Array)) &&
        (!data.key?("line_items_attributes") || (data["line_items_attributes"].is_a?(Array) && data["line_items_attributes"].all? { |item| item.is_a?(Hash) && (!item.key?("amount_only") || [ true, false ].include?(item["amount_only"])) }))
      errors.add(:data, "is too large or has an invalid format")
      return
    end
    ids = Array(data["game_ids"])
    errors.add(:data, "contains games from a different year") unless season.games.where(id: ids).count == ids.uniq.size
    item_ids = Array(data["line_items_attributes"]).filter_map { |item| item["id"].presence }
    if item_ids.any? && (!invoice || invoice.line_items.where(id: item_ids).count != item_ids.uniq.size)
      errors.add(:data, "contains line items from a different invoice")
    end
  end
end
