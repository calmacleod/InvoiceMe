class OfficialPaymentImport < ApplicationRecord
  TIMEOUT = 30.minutes
  TIMEOUT_MESSAGE = "The Horizon import timed out. Pull from Horizon again.".freeze

  belongs_to :season

  scope :active, -> { where(status: %w[queued running]) }

  def self.expire_stalled!
    active.where(updated_at: ...TIMEOUT.ago).update_all(status: "failed", error: TIMEOUT_MESSAGE, updated_at: Time.current)
  end

  def self.start!(season, connection)
    expire_stalled!
    import = season.official_payment_imports.create!
    through = Date.new(season.year, 12, 31)
    job = OfficialPaymentImportJob.perform_later(import.id, connection.id, through.iso8601)
    raise ActiveJob::EnqueueError unless job&.successfully_enqueued?

    import
  rescue ActiveJob::EnqueueError
    import&.update!(status: "failed", error: "The import could not be queued.")
    raise
  end

  def props
    fields = as_json(only: %i[status error organization_name official_count excluded_games changed_cheques updated_at])
    if status.in?(%w[queued running]) && updated_at < TIMEOUT.ago
      fields.merge!("status" => "failed", "error" => TIMEOUT_MESSAGE)
    end
    fields
  end

  def apply!(rows, excluded, connection:)
    with_lock do
      return unless status == "running"

      changed_cheques = []
      existing = season.official_payments.where.not(horizon_user_id: nil).index_by(&:horizon_user_id)
      verify_source!(connection, existing.values, rows)
      incoming = rows.keys.sort_by { |user_id| [ rows.fetch(user_id).fetch(:name).downcase, user_id ] }
      (existing.keys | incoming).each do |user_id|
        row = rows.fetch(user_id, {})
        payment = existing[user_id] || season.official_payments.new(horizon_user_id: user_id)
        payment.reload if payment.persisted?
        name = row.fetch(:name, payment.official_name)
        assignments = row.fetch(:assignments, [])
        if payment.cheque_number
          changed_cheques << payment.id if payment.official_name != name || payment.assignments != assignments
          next
        end
        payment.assign_attributes(official_name: name, assignments: assignments)
        next unless payment.has_changes_to_save?

        payment.update!(reviewed_at: nil)
      end
      update!(status: "completed", horizon_connection_id: connection.id, organization_name: connection.organization_name,
        official_count: rows.size, excluded_games: excluded, changed_cheques: changed_cheques)
    end
  end

  private

  def verify_source!(connection, payments, rows)
    previous_id = season.official_payment_imports.where(status: "completed").order(id: :desc).pick(:horizon_connection_id)
    return if previous_id.nil? || previous_id == connection.id || payments.empty?

    previous_events = payments.flat_map(&:assignments).map { |assignment| assignment.fetch("event_id") }.to_set
    incoming_events = rows.values.flat_map { |row| row.fetch(:assignments) }.map { |assignment| assignment.fetch("event_id") }
    unless incoming_events.any? { |event_id| previous_events.include?(event_id) }
      raise Horizon::Client::ConfigurationError, "The new Horizon connection has no games in common with this year's register. Check the organization."
    end
  end
end
