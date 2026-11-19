class CreateLineItemPrivateBreakdowns < ActiveRecord::Migration[8.1]
  def change
    create_table :line_item_private_breakdowns do |t|
      t.references :line_item, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :data, null: false, default: "{}"
      t.timestamps
    end
    add_index :line_item_private_breakdowns, [ :user_id, :line_item_id ], unique: true
  end
end
