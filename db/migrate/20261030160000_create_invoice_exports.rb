class CreateInvoiceExports < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_exports do |t|
      t.references :invoice, null: false, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.string :step, null: false, default: "waiting"
      t.integer :attempts, null: false, default: 0
      t.text :error
      t.datetime :retry_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :invoice_exports, :invoice_id, unique: true,
      where: "status IN ('queued', 'running', 'retrying')", name: "index_one_active_export_per_invoice"
  end
end
