class CreateHorizonGameSyncs < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :horizon_cancelled, :string
    create_table :horizon_game_syncs do |t|
      t.references :season, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :horizon_connection, null: false, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.integer :pages_fetched, null: false, default: 0
      t.integer :total_pages
      t.json :games, null: false, default: []
      t.text :error
      t.datetime :completed_at
      t.timestamps
    end
    add_index :horizon_game_syncs, "(1)", unique: true, where: "status IN ('queued', 'running')", name: "index_one_active_horizon_game_sync"
  end
end
