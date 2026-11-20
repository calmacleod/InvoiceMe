class AddAdjustmentsToOfficialPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :official_payments, :adjustments, :json, default: [], null: false
  end
end
