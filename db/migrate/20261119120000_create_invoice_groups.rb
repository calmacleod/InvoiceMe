class CreateInvoiceGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_groups do |t|
      t.references :season, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    create_table :invoice_group_games do |t|
      t.references :invoice_group, null: false, foreign_key: true, index: false
      t.references :game, null: false, foreign_key: true
      t.index %i[invoice_group_id game_id], unique: true
    end

    add_reference :invoices, :invoice_group, foreign_key: true
    add_reference :invoice_drafts, :invoice_group, foreign_key: true
  end
end
