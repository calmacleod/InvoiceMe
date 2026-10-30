class AddGameFiltersToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :game_filters, :json, default: {}, null: false
  end
end
