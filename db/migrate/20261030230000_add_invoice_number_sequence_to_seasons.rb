class AddInvoiceNumberSequenceToSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :seasons, :last_invoice_sequence, :integer, default: 0, null: false
  end
end
