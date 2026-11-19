class InvoiceGame < ApplicationRecord
  belongs_to :invoice
  belongs_to :game
  validate do
    errors.add(:base, "Cannot change games on a finalized invoice") if invoice.finalized_at_in_database && !invoice.backfilling_group_game?(game_id)
  end
end
