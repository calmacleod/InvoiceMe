class ExpenseLineItem < ApplicationRecord
  belongs_to :expense, inverse_of: :line_items

  normalizes :description, with: ->(value) { value.strip }
  normalizes :category, with: ->(value) { value.strip.presence }

  validates :description, presence: true, length: { maximum: 250 }
  validates :category, length: { maximum: 100 }
  validates :amount_cents, numericality: { only_integer: true, in: -Expense::MAX_CENTS..Expense::MAX_CENTS }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
