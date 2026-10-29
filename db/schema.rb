# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_29_000100) do
  create_table "games", force: :cascade do |t|
    t.integer "season_id", null: false
    t.string "external_id", null: false
    t.string "code"
    t.date "date", null: false
    t.string "time"
    t.string "home_team"
    t.string "away_team"
    t.string "location"
    t.json "officials", default: [], null: false
    t.integer "fees_cents", default: 0, null: false
    t.json "source", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id", "external_id"], name: "index_games_on_season_id_and_external_id", unique: true
    t.index ["season_id"], name: "index_games_on_season_id"
  end

  create_table "google_connections", force: :cascade do |t|
    t.string "email", null: false
    t.text "refresh_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "invoice_games", force: :cascade do |t|
    t.integer "invoice_id", null: false
    t.integer "game_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_invoice_games_on_game_id"
    t.index ["invoice_id", "game_id"], name: "index_invoice_games_on_invoice_id_and_game_id", unique: true
    t.index ["invoice_id"], name: "index_invoice_games_on_invoice_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "season_id", null: false
    t.string "number", null: false
    t.string "recipient", null: false
    t.string "contact"
    t.text "recipient_address"
    t.string "description", null: false
    t.date "issued_on", null: false
    t.date "due_on"
    t.text "public_notes"
    t.text "private_notes"
    t.json "issuer_snapshot"
    t.json "destination_snapshot"
    t.datetime "finalized_at"
    t.datetime "published_at"
    t.string "google_doc_id"
    t.string "google_pdf_id"
    t.integer "ledger_row"
    t.string "publish_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id", "number"], name: "index_invoices_on_season_id_and_number", unique: true
    t.index ["season_id"], name: "index_invoices_on_season_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.integer "invoice_id", null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 12, scale: 3, null: false
    t.integer "rate_cents", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_line_items_on_invoice_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "invoice_id", null: false
    t.integer "amount_cents", null: false
    t.date "received_on", null: false
    t.string "method", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_payments_on_invoice_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.integer "year", null: false
    t.string "drive_folder_id"
    t.string "pdf_folder_id"
    t.string "spreadsheet_id"
    t.string "sheet_name", default: "2026 invoices", null: false
    t.integer "ledger_start_row", default: 3, null: false
    t.json "issuer", default: {}, null: false
    t.json "import_mapping", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["year"], name: "index_seasons_on_year", unique: true
  end

  add_foreign_key "games", "seasons"
  add_foreign_key "invoice_games", "games"
  add_foreign_key "invoice_games", "invoices"
  add_foreign_key "invoices", "seasons"
  add_foreign_key "line_items", "invoices"
  add_foreign_key "payments", "invoices"
end
