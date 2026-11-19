class InvoiceGroupGame < ApplicationRecord
  belongs_to :invoice_group
  belongs_to :game
  validate do
    errors.add(:game, "must belong to the invoice group's year") if game && invoice_group && game.season_id != invoice_group.season_id
  end
end
