class ExpenseSheetSync < ApplicationRecord
  belongs_to :season
  enum :status, %w[idle queued running succeeded failed].index_with(&:itself), validate: true

  def self.enqueue_for(season)
    sync = nil
    token = nil
    season.with_lock do
      raise GoogleApi::Error, "Set the Financials folder for this year in Settings first." if season.financials_folder_id.blank?
      raise GoogleApi::Error, "Connect the treasurer Google account in Settings first." unless GoogleApi.configured? && GoogleConnection.exists?

      sync = season.expense_sheet_sync || season.build_expense_sheet_sync
      unless sync.active?
        token = SecureRandom.uuid
        sync.update!(status: "queued", run_token: token, error: nil)
      end
    end
    return sync unless token

    begin
      job = SyncExpenseSheetJob.perform_later(sync.id, token)
      raise ActiveJob::EnqueueError, "Sync was not queued" unless job&.successfully_enqueued?
    rescue StandardError => error
      Rails.error.report(error)
      sync.update!(status: "failed", error: "The expense sync could not be queued. Try again shortly.")
      raise GoogleApi::Error, sync.error
    end
    sync
  end

  def self.for_season(season)
    sync = season.expense_sheet_sync || season.build_expense_sheet_sync
    sync.progress
  end

  def active? = (queued? || running?) && updated_at && updated_at > 15.minutes.ago

  def progress
    same_folder = folder_id.present? && folder_id == season.financials_folder_id
    interrupted = (queued? || running?) && !active?
    {
      ready: season.financials_folder_id.present? && GoogleApi.configured? && GoogleConnection.exists?,
      folder_configured: season.financials_folder_id.present?,
      status: interrupted ? "failed" : status,
      active: active?,
      stale: !same_folder || synced_revision != season.expense_revision,
      url: same_folder && spreadsheet_id.present? ? "https://docs.google.com/spreadsheets/d/#{spreadsheet_id}/edit" : nil,
      synced_at: same_folder ? synced_at : nil,
      error: interrupted ? "The previous sync did not finish. Try syncing again." : error
    }
  end
end
