class AddNotesToOfficialPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :official_payments, :visible_note, :text

    create_table :official_payment_private_notes do |t|
      t.references :official_payment, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :private_note, null: false
      t.timestamps
    end
    add_index :official_payment_private_notes, %i[official_payment_id user_id], unique: true
  end
end
