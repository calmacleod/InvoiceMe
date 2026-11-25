class OfficialPayment < ApplicationRecord
  AMOUNTS = %i[game_fee_adjustment travel_ot_adjustment evaluations prepayment_refund registration banquet next_year_prepayment other].freeze
  SIGNED_AMOUNTS = %i[game_fee_adjustment travel_ot_adjustment other].freeze
  REGISTER_FIELDS = {
    registration: "OFOA registration", banquet: "Banquet", next_year_prepayment: "Next year’s prepayment",
    evaluations: "Evaluations", prepayment_refund: "Prepayment refund",
    game_fee_adjustment: "Game fee adjustment", travel_ot_adjustment: "Travel/OT adjustment", other: "Other"
  }.freeze
  CHEQUE_FIELDS = %i[cheque_number deposited_on cheque_delivery].freeze
  AMOUNT_COLUMNS = AMOUNTS.map { |field| :"#{field}_cents" }.freeze
  REGISTER_AMOUNT_FIELDS = (AMOUNT_COLUMNS + %i[game_fees_cents travel_ot_cents association_fee_cents additional_items_cents earnings_before_deductions_cents net_cents]).freeze
  EARNINGS_FIELDS = (AMOUNT_COLUMNS + %i[assignments official_name adjustments]).freeze
  MAX_CENTS = 100_000_000
  MAX_ADJUSTMENTS = 50
  NOTE_MAX_LENGTH = 2_000
  CHEQUE_NUMBER_MAX_LENGTH = 40

  belongs_to :season
  has_many :private_notes, class_name: "OfficialPaymentPrivateNote", dependent: :destroy, inverse_of: :official_payment

  scope :in_payment_order, -> { order(arel_table[:payment_number].asc.nulls_last, :id) }

  before_validation :release_unpayable_cheque_assignment
  before_save :assign_payment_number
  after_save :compact_draft_sequence, if: -> { saved_change_to_payment_number? && payment_number.nil? }
  after_destroy :compact_draft_sequence, if: -> { payment_number && cheque_number.nil? }

  normalizes :official_name, with: ->(name) { name.squish }
  normalizes :cheque_number, :cheque_delivery, with: ->(value) { value.strip.presence }
  normalizes :visible_note, with: ->(value) { value.gsub(/\r\n?/, "\n").strip.presence }
  validates :official_name, presence: true, length: { maximum: 100 }
  validates :official_name, uniqueness: { scope: :season_id, case_sensitive: false, conditions: -> { where(horizon_user_id: nil) } }, if: -> { horizon_user_id.nil? }
  validates :cheque_number, uniqueness: { scope: :season_id }, length: { maximum: CHEQUE_NUMBER_MAX_LENGTH }, allow_nil: true
  validates :cheque_delivery, length: { maximum: 100 }
  validates :visible_note, length: { maximum: NOTE_MAX_LENGTH }
  validates :visible_note, format: { without: /[\u0000-\u0008\u000B\u000C\u000E-\u001F\uFFFE\uFFFF]/, message: "contains unsupported characters" }, allow_nil: true
  validates :deposited_on, comparison: { less_than_or_equal_to: -> { Date.current } }, allow_nil: true
  validates(*SIGNED_AMOUNTS.map { |field| :"#{field}_cents" }, numericality: { only_integer: true, in: -MAX_CENTS..MAX_CENTS })
  validates(*(AMOUNTS - SIGNED_AMOUNTS).map { |field| :"#{field}_cents" }, numericality: { only_integer: true, in: 0..MAX_CENTS })
  validate :valid_cheque
  validate :valid_adjustments

  def self.update_register!(scope, rows)
    inputs = rows.index_by { |row| row[:id].to_s }
    transaction do
      payments = scope.where(id: inputs.keys).in_payment_order.to_a
      if inputs.size != rows.size || payments.size != inputs.size
        raise ActiveRecord::StaleObjectError.new(new, "edit register")
      end

      payments.each do |payment|
        row = inputs.fetch(payment.id.to_s)
        if payment.cheque_recorded? || payment.lock_version.to_s != row[:lock_version].to_s
          raise ActiveRecord::StaleObjectError.new(payment, "edit register")
        end
      end

      changed = payments.select do |payment|
        # An earlier edit in this batch can move this payment up in the sequence.
        payment.reload
        yield payment, inputs.fetch(payment.id.to_s)
        next false unless payment.has_changes_to_save?

        payment.update!(reviewed_at: nil)
      end
      changed.each(&:reload)
    end
  end

  def self.compact_draft_sequence!(season_id)
    payments = where(season_id: season_id)
    last_assigned = payments.where.not(cheque_number: nil).maximum(:payment_number).to_i
    drafts = payments.where(cheque_number: nil, payment_number: (last_assigned + 1)..)
    drafts.order(:payment_number).pluck(:id, :payment_number).each.with_index(last_assigned + 1) do |(id, number), next_number|
      payments.where(id: id).update_all(payment_number: next_number) if number != next_number
    end
  end

  def imported_game_fees_cents = assignments.sum { |entry| entry.fetch("fee_cents") }
  def imported_travel_ot_cents = assignments.sum { |entry| entry.fetch("travel_ot_cents") }
  def horizon_deductions_cents = assignments.sum { |entry| entry.fetch("deductions_cents") }
  def game_count = assignments.filter_map { |entry| entry["event_id"].presence }.uniq.size
  def game_fees_cents = imported_game_fees_cents + game_fee_adjustment_cents
  def travel_ot_cents = imported_travel_ot_cents + travel_ot_adjustment_cents
  def additional_items_cents = adjustments.sum { |item| item.fetch("amount_cents") }
  def miscellaneous_cents = other_cents + additional_items_cents

  def register_amounts
    REGISTER_AMOUNT_FIELDS.index_with { |field| public_send(field) }
  end

  def self.register_totals(payments)
    payments.each_with_object(REGISTER_AMOUNT_FIELDS.index_with(0)) do |payment, totals|
      payment.register_amounts.each { |field, cents| totals[field] += cents }
    end
  end

  def association_fee_cents
    base = game_fees_cents.clamp(0, 250_000) * 8
    upper = (game_fees_cents - 250_000).clamp(0, 200_000) * 4
    (base + upper + 50) / 100
  end

  def net_game_fees_cents = game_fees_cents - association_fee_cents
  def earnings_before_deductions_cents = net_game_fees_cents + travel_ot_cents + evaluations_cents + prepayment_refund_cents + miscellaneous_cents
  def net_cents = earnings_before_deductions_cents - registration_cents - banquet_cents - next_year_prepayment_cents
  def payable? = net_cents.positive?
  def cheque_recorded? = cheque_number.present? && reviewed_at.present?

  def status
    if deposited_on
      "Deposited"
    elsif cheque_recorded?
      "Cheque recorded"
    elsif reviewed_at
      "Reviewed"
    else
      "Needs review"
    end
  end

  def private_note_for(user)
    private_notes.find_by(user: user)&.private_note
  end

  def update_from_form!(values, user:, lock_version:)
    with_lock do
      raise ActiveRecord::StaleObjectError.new(self, "update") unless lock_version.to_s == self.lock_version.to_s
      validate_note_types!(values)

      assign_amounts(values.slice(*AMOUNTS))
      assign_attributes(values.slice(*CHEQUE_FIELDS, :visible_note))
      assign_adjustments(values[:adjustments]) if values.key?(:adjustments)
      if values.key?(:reviewed)
        self.reviewed_at = values[:reviewed] ? (reviewed_at || Time.current) : nil
      elsif EARNINGS_FIELDS.any? { |field| will_save_change_to_attribute?(field) }
        self.reviewed_at = nil
      end
      private_note_changed = values.key?(:private_note) && save_private_note!(user, values[:private_note])
      save!
      touch if private_note_changed && !saved_changes?
    end
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

  def validate_note_types!(values)
    invalid = values.slice(:visible_note, :private_note).reject { |_, value| value.nil? || value.is_a?(String) }
    return if invalid.empty?

    invalid.each_key { |field| errors.add(field, "must be text") }
    raise ActiveRecord::RecordInvalid, self
  end

  def save_private_note!(user, value)
    note = private_notes.find_by(user: user)
    if value.present?
      note ||= private_notes.build(user: user)
      note.private_note = value
      note.changed? && note.save!
    elsif note
      note.destroy!
    end
  end

  def assign_payment_number
    if payable?
      self.payment_number ||= self.class.where(season_id: season_id).maximum(:payment_number).to_i + 1
    else
      self.payment_number = nil
    end
  end

  def compact_draft_sequence
    self.class.compact_draft_sequence!(season_id)
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

  def cheque_recorded_in_database?
    cheque_number_in_database.present? && reviewed_at_in_database.present?
  end

  def release_unpayable_cheque_assignment
    return if cheque_number.blank? || will_save_change_to_cheque_number? || cheque_recorded_in_database?

    self.cheque_number = nil unless payable?
  end

  def valid_cheque
    if cheque_number
      errors.add(:cheque_number, "requires a positive net amount") unless payable?
      if !reviewed_at && (deposited_on || cheque_delivery || cheque_recorded_in_database?)
        errors.add(:cheque_number, "requires reviewed earnings for deposit, delivery or an already recorded cheque")
      end
    elsif deposited_on || cheque_delivery
      errors.add(:cheque_number, "is required for deposit or delivery details")
    end
    if cheque_recorded_in_database? && EARNINGS_FIELDS.any? { |field| will_save_change_to_attribute?(field) }
      errors.add(:base, "Clear the recorded cheque before changing earnings.")
    end
  end
end
