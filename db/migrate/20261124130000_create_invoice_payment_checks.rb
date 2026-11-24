class CreateInvoicePaymentChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_payment_checks do |t|
      t.references :season, null: false, index: { unique: true }, foreign_key: true
      t.string :status, null: false, default: "idle"
      t.string :run_token
      t.integer :checked_count, null: false, default: 0
      t.integer :imported_count, null: false, default: 0
      t.integer :review_count, null: false, default: 0
      t.datetime :finished_at
      t.string :error
      t.timestamps
    end
  end
end
