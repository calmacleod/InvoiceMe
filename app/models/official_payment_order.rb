class OfficialPaymentOrder
  COLUMNS = (%w[official_name payment_number game_count cheque_number deposited_on status] + OfficialPayment::REGISTER_AMOUNT_FIELDS.map(&:to_s)).freeze
  DIRECTIONS = %w[asc desc].freeze
  STATUSES = [ "Needs review", "Reviewed", "Cheque recorded", "Deposited" ].freeze

  def initialize(column, direction)
    raise ArgumentError, "Unknown official payment sort column" if column && !COLUMNS.include?(column)
    raise ArgumentError, "direction must be asc or desc" if direction && !DIRECTIONS.include?(direction)

    @column = column
    @direction = direction || "asc"
  end

  def apply(payments)
    return payments unless @column

    present, missing = payments.map.with_index { |payment, index| [ sort_value(payment), index, payment ] }
      .partition { |value,| !value.nil? }
    direction = @direction == "asc" ? 1 : -1
    present.sort! do |(left, left_index), (right, right_index)|
      (direction * (left <=> right)).nonzero? || (left_index <=> right_index)
    end
    (present + missing).map(&:last)
  end

  def props = { column: @column, direction: @direction }

  private

  def sort_value(payment)
    case @column
    when "official_name" then payment.official_name.downcase
    when "cheque_number"
      number = payment.cheque_number
      return unless number

      match = OfficialChequeSequence::NUMBER_PATTERN.match(number)
      match ? [ match[1].downcase, match[2].to_i ] : [ number.downcase, 0 ]
    when "status" then STATUSES.index(payment.status)
    else payment.public_send(@column)
    end
  end
end
