class OfficialPayment < ApplicationRecord
  AMOUNTS = %i[game_fee_adjustment travel_ot_adjustment evaluations prepayment_refund registration banquet next_year_prepayment other].freeze
  SIGNED_AMOUNTS = %i[game_fee_adjustment travel_ot_adjustment other].freeze
  CHEQUE_FIELDS = %i[cheque_number deposited_on cheque_delivery].freeze
  EARNINGS_FIELDS = AMOUNTS.map { |field| :"#{field}_cents" } + %i[assignments official_name]
  MAX_CENTS = 100_000_000

  belongs_to :season

  normalizes :official_name, with: ->(name) { name.squish }
  normalizes :cheque_number, :cheque_delivery, with: ->(value) { value.strip.presence }
  validates :official_name, presence: true, length: { maximum: 100 }
  validates :official_name, uniqueness: { scope: :season_id, case_sensitive: false, conditions: -> { where(horizon_user_id: nil) } }, if: -> { horizon_user_id.nil? }
  validates :cheque_number, uniqueness: { scope: :season_id }, length: { maximum: 40 }, allow_nil: true
  validates :cheque_delivery, length: { maximum: 100 }
  validates :deposited_on, comparison: { less_than_or_equal_to: -> { Date.current } }, allow_nil: true
  validates(*SIGNED_AMOUNTS.map { |field| :"#{field}_cents" }, numericality: { only_integer: true, in: -MAX_CENTS..MAX_CENTS })
  validates(*(AMOUNTS - SIGNED_AMOUNTS).map { |field| :"#{field}_cents" }, numericality: { only_integer: true, in: 0..MAX_CENTS })
  validate :valid_cheque

  def imported_game_fees_cents = assignments.sum { |entry| entry.fetch("fee_cents") }
  def imported_travel_ot_cents = assignments.sum { |entry| entry.fetch("travel_ot_cents") }
  def horizon_deductions_cents = assignments.sum { |entry| entry.fetch("deductions_cents") }
  def game_fees_cents = imported_game_fees_cents + game_fee_adjustment_cents
  def travel_ot_cents = imported_travel_ot_cents + travel_ot_adjustment_cents

  def association_fee_cents
    base = game_fees_cents.clamp(0, 250_000) * 8
    upper = (game_fees_cents - 250_000).clamp(0, 200_000) * 4
    (base + upper + 50) / 100
  end

  def net_cents
    game_fees_cents + travel_ot_cents + evaluations_cents + prepayment_refund_cents + other_cents -
      association_fee_cents - registration_cents - banquet_cents - next_year_prepayment_cents
  end

  def status
    if deposited_on
      "Deposited"
    elsif cheque_number
      "Cheque recorded"
    elsif reviewed_at
      "Reviewed"
    else
      "Needs review"
    end
  end

  def update_from_form!(values)
    amounts = values.slice(*AMOUNTS).to_h do |field, value|
      key = :"#{field}_cents"
      begin
        text = value.to_s.strip
        amount = text.blank? ? 0 : MoneyValue.cents(text.delete_prefix("-"))
        [ key, text.start_with?("-") ? -amount : amount ]
      rescue ArgumentError
        errors.add(field, "must be a dollar amount with up to two decimal places")
        raise ActiveRecord::RecordInvalid, self
      end
    end
    assign_attributes(amounts.merge(values.slice(*CHEQUE_FIELDS)))
    self.reviewed_at = values[:reviewed] ? (reviewed_at || Time.current) : nil
    save!
  end

  private

  def valid_cheque
    if cheque_number
      errors.add(:cheque_number, "requires reviewed earnings and a positive net amount") unless reviewed_at && net_cents.positive?
    elsif deposited_on || cheque_delivery
      errors.add(:cheque_number, "is required for deposit or delivery details")
    end
    if cheque_number_in_database.present? && EARNINGS_FIELDS.any? { |field| will_save_change_to_attribute?(field) }
      errors.add(:base, "Clear the recorded cheque before changing earnings.")
    end
  end
end
