class LineItem < ApplicationRecord
  belongs_to :invoice
  validates :description, presence: true, length: { maximum: 1000 }
  validates :quantity, numericality: { greater_than: 0, less_than: 1_000_000 }
  validates :rate_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 100_000_000 }
  validate { errors.add(:rate, "must be a valid amount with at most two decimal places") if @invalid_rate }
  validate do
    raw_quantity = quantity_before_type_cast
    if raw_quantity.is_a?(String) && !raw_quantity.match?(/\A\d+(?:\.\d{1,3})?\z/)
      errors.add(:quantity, "must have at most three decimal places")
    end
    errors.add(:base, "Finalized line items cannot be edited") if invoice&.finalized_at_in_database && changed?
  end
  def rate = rate_cents && BigDecimal(rate_cents) / 100
  def rate=(value)
    self.rate_cents = MoneyValue.cents(value)
    @invalid_rate = false
  rescue ArgumentError
    self.rate_cents = nil
    @invalid_rate = true
  end
  def total_cents = ((quantity || 0) * (rate_cents || 0)).round(0).to_i
end
