class InvoiceGame < ApplicationRecord
  belongs_to :invoice
  belongs_to :game
  validate do
    errors.add(:base, "Cannot change games on a finalized invoice") if invoice.finalized_at_in_database
  end
end
