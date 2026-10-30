class AddAlreadyInvoicedToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :already_invoiced, :boolean, default: false, null: false
  end
end
