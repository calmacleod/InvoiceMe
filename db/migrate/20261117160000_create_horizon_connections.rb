class CreateHorizonConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :horizon_connections do |t|
      t.text :authorization_code, null: false
      t.text :access_token
      t.datetime :access_token_expires_at
      t.string :organization_name
      t.timestamps
    end
  end
end
