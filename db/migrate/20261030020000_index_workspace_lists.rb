class IndexWorkspaceLists < ActiveRecord::Migration[8.1]
  def change
    add_index :games, [ :season_id, :date, :external_id ], order: { date: :desc }
    add_index :invoices, [ :season_id, :issued_on, :id ], order: { issued_on: :desc, id: :desc }
  end
end
