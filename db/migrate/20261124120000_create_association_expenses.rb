class CreateAssociationExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :seasons, :financials_folder_id, :string
    add_column :seasons, :expense_revision, :integer, default: 0, null: false

    create_table :expenses do |t|
      t.references :season, null: false, foreign_key: true
      t.string :payee, null: false
      t.string :description, null: false
      t.string :category, null: false
      t.date :incurred_on, null: false
      t.bigint :total_cents, null: false
      t.boolean :paid, null: false, default: false
      t.date :paid_on
      t.string :payment_method
      t.string :cheque_number
      t.string :reference
      t.text :notes
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      t.index %i[season_id incurred_on id], name: "index_expenses_for_register"
    end

    create_table :expense_line_items do |t|
      t.references :expense, null: false, foreign_key: true
      t.string :description, null: false
      t.string :category
      t.bigint :amount_cents, null: false
      t.integer :position, null: false
      t.timestamps
    end

    create_table :expense_sheet_syncs do |t|
      t.references :season, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "idle"
      t.string :run_token
      t.string :folder_id
      t.string :spreadsheet_id
      t.integer :synced_revision
      t.datetime :synced_at
      t.text :error
      t.timestamps
    end
  end
end
