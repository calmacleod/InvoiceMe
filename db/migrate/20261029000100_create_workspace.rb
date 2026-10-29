class CreateWorkspace < ActiveRecord::Migration[8.1]
  def change
    create_table :seasons do |t|
      t.integer :year, null: false
      t.string :drive_folder_id
      t.string :pdf_folder_id
      t.string :spreadsheet_id
      t.string :sheet_name, default: "2026 invoices", null: false
      t.integer :ledger_start_row, default: 3, null: false
      t.json :issuer, default: {}, null: false
      t.json :import_mapping, default: {}, null: false
      t.timestamps
    end
    add_index :seasons, :year, unique: true
    create_table :games do |t|
      t.references :season, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :code
      t.date :date, null: false
      t.string :time
      t.string :home_team
      t.string :away_team
      t.string :location
      t.json :officials, default: [], null: false
      t.integer :fees_cents, default: 0, null: false
      t.json :source, default: [], null: false
      t.timestamps
    end
    add_index :games, [ :season_id, :external_id ], unique: true
    create_table :invoices do |t|
      t.references :season, null: false, foreign_key: true
      t.string :number, null: false
      t.string :recipient, null: false
      t.string :contact
      t.text :recipient_address
      t.string :description, null: false
      t.date :issued_on, null: false
      t.date :due_on
      t.text :public_notes
      t.text :private_notes
      t.json :issuer_snapshot
      t.json :destination_snapshot
      t.datetime :finalized_at
      t.datetime :published_at
      t.string :google_doc_id
      t.string :google_pdf_id
      t.integer :ledger_row
      t.string :publish_error
      t.timestamps
    end
    add_index :invoices, [ :season_id, :number ], unique: true
    create_table :line_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.integer :rate_cents, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    create_table :invoice_games do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.timestamps
    end
    add_index :invoice_games, [ :invoice_id, :game_id ], unique: true
    create_table :payments do |t|
      t.references :invoice, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.date :received_on, null: false
      t.string :method, null: false
      t.text :notes
      t.timestamps
    end
    create_table :google_connections do |t|
      t.string :email, null: false
      t.text :refresh_token, null: false
      t.timestamps
    end
  end
end
