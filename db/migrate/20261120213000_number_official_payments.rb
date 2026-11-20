class NumberOfficialPayments < ActiveRecord::Migration[8.1]
  def up
    add_column :official_payments, :payment_number, :integer
    execute <<~SQL
      WITH numbers AS (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY season_id ORDER BY lower(official_name), id) AS payment_number
        FROM official_payments
      )
      UPDATE official_payments
      SET payment_number = (SELECT payment_number FROM numbers WHERE numbers.id = official_payments.id)
    SQL
    change_column_null :official_payments, :payment_number, false
    add_index :official_payments, [ :season_id, :payment_number ], unique: true
  end

  def down
    remove_index :official_payments, [ :season_id, :payment_number ]
    remove_column :official_payments, :payment_number
  end
end
