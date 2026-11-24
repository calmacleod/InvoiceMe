class Expense < ApplicationRecord
  MAX_CENTS = 999_999_999_999
  DEFAULT_CATEGORIES = [ "Meetings", "Food and refreshments", "Training", "Banquets and events", "Equipment", "Administration" ].freeze

  belongs_to :season
  has_many :line_items, -> { order(:position, :id) }, class_name: "ExpenseLineItem", inverse_of: :expense, dependent: :destroy, autosave: true

  normalizes :payee, :description, :category, with: ->(value) { value.strip }
  normalizes :payment_method, :cheque_number, :reference, :notes, with: ->(value) { value.strip.presence }

  validates :payee, :description, :category, :incurred_on, presence: true
  validates :payee, :description, length: { maximum: 250 }
  validates :category, :payment_method, :cheque_number, :reference, length: { maximum: 100 }
  validates :notes, length: { maximum: 5_000 }
  validates :total_cents, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_CENTS }
  validates :paid, inclusion: { in: [ true, false ] }
  validate :validate_details

  after_save :increment_expense_revision
  after_destroy :increment_expense_revision

  def save_details!(attributes)
    details = attributes.dup
    items = details.delete(:line_items)
    assign_attributes(details)
    assign_line_items(items) if items
    save!
  end

  def itemized_cents = current_items.sum { |item| item.amount_cents.to_i }
  def remainder_cents = total_cents.to_i - itemized_cents

  def allocations
    values = current_items.map { |item| [ item.category.presence || category, item.amount_cents ] }
    values << [ category, remainder_cents ] unless remainder_cents.zero?
    values
  end

  def details
    as_json(only: %i[id season_id payee description category incurred_on total_cents paid paid_on payment_method cheque_number reference notes lock_version created_at updated_at]).merge(
      itemized_cents: itemized_cents, remainder_cents: remainder_cents,
      line_items: current_items.map { |item| item.as_json(only: %i[id position description category amount_cents]) }
    )
  end

  private

  def current_items = line_items.reject(&:marked_for_destruction?).sort_by(&:position)

  def assign_line_items(items)
    remaining = line_items.to_a.index_by(&:id)
    items.each_with_index do |attrs, position|
      attrs = attrs.to_h.symbolize_keys
      item_id = attrs.delete(:id).presence
      item = if item_id
        remaining.delete(Integer(item_id.to_s, 10)) || raise(ArgumentError, "Line item IDs must belong to this expense and appear once")
      else
        line_items.build
      end
      item.assign_attributes(attrs.merge(position: position))
    end
    remaining.each_value(&:mark_for_destruction)
    self.updated_at = Time.current if persisted?
  end

  def validate_details
    if !paid && [ paid_on, payment_method, cheque_number ].any?(&:present?)
      errors.add(:paid, "must be selected before entering payment details")
    end
    if total_cents && itemized_cents > total_cents
      errors.add(:line_items, "add up to more than the expense total")
    end
  end

  def increment_expense_revision
    Season.increment_counter(:expense_revision, season_id)
  end
end
