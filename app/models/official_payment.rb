class OfficialPayment < ApplicationRecord
  AMOUNTS = %i[game_fee_adjustment travel_ot_adjustment evaluations prepayment_refund registration banquet next_year_prepayment other].freeze
  SIGNED_AMOUNTS = %i[game_fee_adjustment travel_ot_adjustment other].freeze
  REGISTER_FIELDS = {
    registration: "OFOA registration", banquet: "Banquet", next_year_prepayment: "Next year’s prepayment",
    evaluations: "Evaluations", prepayment_refund: "Prepayment refund",
    game_fee_adjustment: "Game fee adjustment", travel_ot_adjustment: "Travel/OT adjustment", other: "Other"
  }.freeze
  CHEQUE_FIELDS = %i[cheque_number deposited_on cheque_delivery].freeze
  EARNINGS_FIELDS = AMOUNTS.map { |field| :"#{field}_cents" } + %i[assignments official_name adjustments]
  MAX_CENTS = 100_000_000
  MAX_ADJUSTMENTS = 50

  belongs_to :season
  attr_readonly :payment_number
  before_create :assign_payment_number

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
  validate :valid_adjustments

  def self.update_register!(scope, rows)
    inputs = rows.index_by { |row| row[:id].to_s }
    transaction do
      payments = scope.where(id: inputs.keys).order(:payment_number).to_a
      if inputs.size != rows.size || payments.size != inputs.size
        raise ActiveRecord::StaleObjectError.new(new, "edit register")
      end

      payments.select do |payment|
        row = inputs.fetch(payment.id.to_s)
        if payment.cheque_number || payment.lock_version.to_s != row[:lock_version].to_s
          raise ActiveRecord::StaleObjectError.new(payment, "edit register")
        end

        yield payment, row
        next false unless payment.has_changes_to_save?

        payment.update!(reviewed_at: nil)
      end
    end
  end

  def imported_game_fees_cents = assignments.sum { |entry| entry.fetch("fee_cents") }
  def imported_travel_ot_cents = assignments.sum { |entry| entry.fetch("travel_ot_cents") }
  def horizon_deductions_cents = assignments.sum { |entry| entry.fetch("deductions_cents") }
  def game_fees_cents = imported_game_fees_cents + game_fee_adjustment_cents
  def travel_ot_cents = imported_travel_ot_cents + travel_ot_adjustment_cents
  def miscellaneous_cents = other_cents + adjustments.sum { |item| item.fetch("amount_cents") }

  def association_fee_cents
    base = game_fees_cents.clamp(0, 250_000) * 8
    upper = (game_fees_cents - 250_000).clamp(0, 200_000) * 4
    (base + upper + 50) / 100
  end

  def net_game_fees_cents = game_fees_cents - association_fee_cents
  def earnings_before_deductions_cents = net_game_fees_cents + travel_ot_cents + evaluations_cents + prepayment_refund_cents + miscellaneous_cents
  def net_cents = earnings_before_deductions_cents - registration_cents - banquet_cents - next_year_prepayment_cents

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
    assign_amounts(values.slice(*AMOUNTS))
    assign_attributes(values.slice(*CHEQUE_FIELDS))
    assign_adjustments(values[:adjustments]) if values.key?(:adjustments)
    if values.key?(:reviewed)
      self.reviewed_at = values[:reviewed] ? (reviewed_at || Time.current) : nil
    elsif EARNINGS_FIELDS.any? { |field| will_save_change_to_attribute?(field) }
      self.reviewed_at = nil
    end
    save!
  end

  def assign_amounts(values)
    assign_attributes(values.to_h { |field, value| [ :"#{field}_cents", parse_amount!(field, value) ] })
  end

  def assign_adjustments(items)
    self.adjustments = items.filter_map do |item|
      label = item[:label].to_s.squish
      next if label.blank? && item[:amount].blank?

      { "label" => label, "amount_cents" => parse_amount!(:adjustments, item[:amount].presence || "invalid") }
    end
  end

  private

  def assign_payment_number
    self.payment_number = self.class.where(season_id: season_id).maximum(:payment_number).to_i + 1
  end

  def parse_amount!(field, value)
    text = value.to_s.strip
    return 0 if text.blank?

    text = "-#{text[1...-1]}" if text.start_with?("(") && text.end_with?(")")
    sign = text.start_with?("-") ? -1 : 1
    sign * MoneyValue.cents(text.delete_prefix("-"))
  rescue ArgumentError
    errors.add(field, "must use dollar amounts with up to two decimal places")
    raise ActiveRecord::RecordInvalid, self
  end

  def valid_adjustments
    if adjustments.length > MAX_ADJUSTMENTS
      errors.add(:adjustments, "can contain at most #{MAX_ADJUSTMENTS} items")
    end
    if adjustments.any? { |item| item["label"].blank? || item["label"].length > 100 || !item["amount_cents"].between?(-MAX_CENTS, MAX_CENTS) }
      errors.add(:adjustments, "need a name up to 100 characters and a valid amount")
    end
  end

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
