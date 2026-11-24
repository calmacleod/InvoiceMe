class OfficialChequeSequence
  class Changed < StandardError; end

  CHANGED_MESSAGE = "The payment register changed. Preview the cheque numbers again.".freeze
  NUMBER_PATTERN = /\A(.*?)([0-9]+)\z/

  def initialize(season)
    @season = season
  end

  def preview(first_cheque_number)
    first = first_cheque_number.to_s.strip
    payments = pending_payments
    numbers = proposed_numbers(first, payments.size)
    rows = payments.zip(numbers).map do |payment, number|
      {
        id: payment.id, payment_number: payment.payment_number, official_name: payment.official_name,
        net_cents: payment.net_cents, cheque_number: number, reviewed: payment.reviewed_at.present?
      }
    end
    { first_cheque_number: first, rows: rows, preview_token: verifier.generate([ @season.id, first, snapshot(payments) ]) }
  end

  def record!(preview_token)
    season_id, first, reviewed_snapshot = verifier.verified(preview_token.to_s)
    raise Changed, CHANGED_MESSAGE unless season_id == @season.id

    OfficialPayment.transaction do
      payments = pending_payments
      raise Changed, CHANGED_MESSAGE unless snapshot(payments) == reviewed_snapshot
      raise ArgumentError, "Review the earnings for every official in the batch before recording cheques." if payments.any? { |payment| !payment.reviewed_at }

      numbers = proposed_numbers(first, payments.size)
      payments.zip(numbers).each { |payment, number| payment.update!(cheque_number: number) }
      payments.size
    end
  rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique
    raise Changed, CHANGED_MESSAGE
  end

  private

  def pending_payments
    @season.official_payments.where(cheque_number: nil).where.not(payment_number: nil)
      .in_payment_order.to_a.select(&:payable?)
  end

  def proposed_numbers(first, count)
    raise ArgumentError, "There are no payable officials awaiting a cheque number." if count.zero?

    length_limit = OfficialPayment::CHEQUE_NUMBER_MAX_LENGTH
    match = NUMBER_PATTERN.match(first) if first.length <= length_limit
    unless match && match[2].to_i.positive?
      raise ArgumentError, "Enter a cheque number ending in a positive number, such as 00125."
    end

    prefix, digits = match.captures
    numbers = Array.new(count) { |index| "#{prefix}#{(digits.to_i + index).to_s.rjust(digits.length, '0')}" }
    raise ArgumentError, "The cheque sequence exceeds the #{length_limit}-character limit." if numbers.last.length > length_limit

    recorded = @season.official_payments.where.not(cheque_number: nil).pluck(:cheque_number).map { |number| cheque_key(number) }.to_set
    conflict = numbers.find { |number| recorded.include?(cheque_key(number)) }
    raise ArgumentError, "Cheque #{conflict} is already recorded. Choose a different starting number." if conflict

    numbers
  end

  def cheque_key(number)
    match = NUMBER_PATTERN.match(number)
    [ match[1].downcase, match[2].to_i ] if match
  end

  def snapshot(payments)
    Digest::SHA256.hexdigest(payments.map { |payment| [ payment.id, payment.payment_number, payment.lock_version ] }.to_json)
  end

  def verifier = Rails.application.message_verifier(:official_cheque_sequence)
end
