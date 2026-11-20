class OfficialPaymentImportJob < ApplicationJob
  queue_as :default

  def perform(import_id, connection_id, through)
    claimed = OfficialPaymentImport.where(id: import_id, status: "queued").update_all(status: "running", updated_at: Time.current)
    return if claimed.zero?

    import = OfficialPaymentImport.find(import_id)
    connection = HorizonConnection.find_by(id: connection_id)
    raise Horizon::Client::ConfigurationError, "Reconnect Horizon and start another import." unless connection

    client = Horizon::Client.new(access_token: connection.access_token_for_request)
    rows, excluded = Horizon::OfficialEarnings.new(client.schedule, from: Date.new(import.season.year, 1, 1), through: Date.iso8601(through)).fetch
    import.apply!(rows, excluded, connection: connection)
  rescue Horizon::Client::Error => error
    fail_import(import_id, error.message)
  rescue ActiveRecord::StaleObjectError
    fail_import(import_id, "A payment changed during the import. Pull from Horizon again.")
  rescue StandardError => error
    fail_import(import_id, "The Horizon import stopped before updating the register.")
    Rails.error.report(error)
  end

  private

  def fail_import(id, message)
    OfficialPaymentImport.where(id: id, status: "running").update_all(status: "failed", error: message, updated_at: Time.current)
  end
end
