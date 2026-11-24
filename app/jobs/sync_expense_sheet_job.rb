class SyncExpenseSheetJob < ApplicationJob
  queue_as :google_exports

  def perform(sync_id, token)
    sync_id = Integer(sync_id)
    sync = ExpenseSheetSync.find_by(id: sync_id)
    return unless sync

    FileUtils.mkdir_p(Rails.root.join("storage/locks"))
    File.open(Rails.root.join("storage/locks/expense-sheet-#{sync_id}.lock"), "w") do |lock|
      lock.flock(File::LOCK_EX)
      next unless sync.reload.run_token == token && (sync.queued? || sync.running?)

      perform_sync(sync, token)
    end
  end

  private

  def perform_sync(sync, token)
    sync.update!(status: "running", error: nil)
    year, folder, revision, register = Season.transaction do
      season = sync.season.reload
      register = ExpenseRegister.new(season)
      register.expenses
      [ season.year, season.financials_folder_id, season.expense_revision, register ]
    end
    id = ExpenseSpreadsheet.new(year: year, folder_id: folder, register: register).sync!
    finish(sync, token, status: "succeeded", folder_id: folder, spreadsheet_id: id, synced_revision: revision, synced_at: Time.current)
  rescue GoogleApi::Error => error
    finish(sync, token, status: "failed", error: error.message)
  rescue StandardError
    finish(sync, token, status: "failed", error: "The sync stopped unexpectedly. Try syncing again.")
    raise
  end

  def finish(sync, token, **attributes)
    sync.with_lock { sync.update!(attributes) if sync.run_token == token }
  end
end
