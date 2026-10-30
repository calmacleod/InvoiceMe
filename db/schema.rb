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

ActiveRecord::Schema[8.1].define(version: 2026_10_30_130000) do
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
    t.index ["season_id", "date", "external_id"], name: "index_games_on_season_id_and_date_and_external_id", order: { date: :desc }
    t.index ["season_id", "external_id"], name: "index_games_on_season_id_and_external_id", unique: true
    t.index ["season_id"], name: "index_games_on_season_id"
  end

  create_table "google_connections", force: :cascade do |t|
    t.string "email", null: false
    t.text "refresh_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "invoice_drafts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "season_id", null: false
    t.integer "invoice_id"
    t.string "client_key", null: false
    t.string "title", default: "Untitled draft", null: false
    t.json "data", default: {}, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_drafts_on_invoice_id"
    t.index ["season_id"], name: "index_invoice_drafts_on_season_id"
    t.index ["user_id", "client_key"], name: "index_invoice_drafts_on_user_id_and_client_key", unique: true
    t.index ["user_id", "invoice_id"], name: "index_invoice_drafts_on_user_id_and_invoice_id", unique: true, where: "invoice_id IS NOT NULL"
    t.index ["user_id", "season_id", "updated_at", "id"], name: "index_invoice_drafts_for_workbench", order: { updated_at: :desc, id: :desc }
    t.index ["user_id"], name: "index_invoice_drafts_on_user_id"
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
    t.index ["season_id", "issued_on", "id"], name: "index_invoices_on_season_id_and_issued_on_and_id", order: { issued_on: :desc, id: :desc }
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

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "games", "seasons"
  add_foreign_key "invoice_drafts", "invoices"
  add_foreign_key "invoice_drafts", "seasons"
  add_foreign_key "invoice_drafts", "users"
  add_foreign_key "invoice_games", "games"
  add_foreign_key "invoice_games", "invoices"
  add_foreign_key "invoices", "seasons"
  add_foreign_key "line_items", "invoices"
  add_foreign_key "payments", "invoices"
  add_foreign_key "sessions", "users"
end
