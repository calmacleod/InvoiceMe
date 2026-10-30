class CreateInvoiceDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_drafts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.references :invoice, foreign_key: true
      t.string :client_key, null: false
      t.string :title, null: false, default: "Untitled draft"
      t.json :data, null: false, default: {}
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :invoice_drafts, [ :user_id, :client_key ], unique: true
    add_index :invoice_drafts, [ :user_id, :invoice_id ], unique: true, where: "invoice_id IS NOT NULL"
    add_index :invoice_drafts, [ :user_id, :season_id, :updated_at, :id ], name: "index_invoice_drafts_for_workbench", order: { updated_at: :desc, id: :desc }
  end
end
