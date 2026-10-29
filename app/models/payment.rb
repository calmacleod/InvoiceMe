class Payment < ApplicationRecord
  belongs_to :invoice
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :received_on, :method, presence: true
  validate do
    errors.add(:base, "Finalize the invoice before recording payments") unless invoice.finalized_at
    errors.add(:amount_cents, "exceeds the outstanding balance") if new_record? && amount_cents.to_i > invoice.owed_cents
  end
end
