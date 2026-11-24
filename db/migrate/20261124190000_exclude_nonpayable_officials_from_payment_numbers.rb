class ExcludeNonpayableOfficialsFromPaymentNumbers < ActiveRecord::Migration[8.1]
  def up
    change_column_null :official_payments, :payment_number, true
    OfficialPayment.reset_column_information

    OfficialPayment.distinct.pluck(:season_id).each do |season_id|
      drafts = OfficialPayment.where(season_id: season_id, cheque_number: nil)
      excluded_ids = drafts.reject(&:payable?).map(&:id)
      drafts.where(id: excluded_ids).update_all(payment_number: nil)
      OfficialPayment.compact_draft_sequence!(season_id)
    end
  end

  def down
    OfficialPayment.reset_column_information
    OfficialPayment.distinct.pluck(:season_id).each do |season_id|
      payments = OfficialPayment.where(season_id: season_id)
      next_number = payments.maximum(:payment_number).to_i + 1
      payments.where(payment_number: nil).order(:id).ids.each.with_index(next_number) do |id, number|
        payments.where(id: id).update_all(payment_number: number)
      end
    end
    change_column_null :official_payments, :payment_number, false
  end
end
