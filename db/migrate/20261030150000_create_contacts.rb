class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :organization, null: false, default: ""
      t.string :email, null: false, default: ""
      t.string :phone, null: false, default: ""
      t.text :address, null: false, default: ""
      t.text :notes, null: false, default: ""
      t.timestamps
    end
    add_index :contacts, [ :user_id, :name, :id ]
  end
end
