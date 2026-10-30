class AddAmountOnlyToLineItems < ActiveRecord::Migration[8.1]
  def change
    add_column :line_items, :amount_only, :boolean, default: false, null: false
  end
end
