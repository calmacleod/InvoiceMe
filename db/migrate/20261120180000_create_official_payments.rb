class CreateOfficialPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :official_payments do |t|
      t.references :season, null: false, foreign_key: true
      t.string :horizon_user_id
      t.string :official_name, null: false
      t.json :assignments, null: false, default: []
      t.integer :game_fee_adjustment_cents, null: false, default: 0
      t.integer :travel_ot_adjustment_cents, null: false, default: 0
      t.integer :evaluations_cents, null: false, default: 0
      t.integer :prepayment_refund_cents, null: false, default: 0
      t.integer :registration_cents, null: false, default: 0
      t.integer :banquet_cents, null: false, default: 0
      t.integer :next_year_prepayment_cents, null: false, default: 0
      t.integer :other_cents, null: false, default: 0
      t.datetime :reviewed_at
      t.string :cheque_number
      t.date :deposited_on
      t.string :cheque_delivery
      t.string :google_doc_id
      t.string :google_doc_digest
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      t.index [ :season_id, :horizon_user_id ], unique: true
      t.index "season_id, lower(official_name)", unique: true, where: "horizon_user_id IS NULL", name: "index_manual_official_payments_on_name"
      t.index [ :season_id, :cheque_number ], unique: true
    end

    create_table :official_payment_imports do |t|
      t.references :season, null: false, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.string :organization_name
      t.integer :horizon_connection_id
      t.string :error
      t.integer :official_count
      t.json :excluded_games, null: false, default: []
      t.json :changed_cheques, null: false, default: []
      t.timestamps
      t.index "(1)", unique: true, where: "status IN ('queued', 'running')", name: "index_one_active_official_payment_import"
    end
  end
end
