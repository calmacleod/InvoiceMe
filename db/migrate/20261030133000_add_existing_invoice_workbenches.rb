class AddExistingInvoiceWorkbenches < ActiveRecord::Migration[8.1]
  def up
    # Older invoices have no author. A sole account can safely own its existing
    # drafts; multi-account installations claim them explicitly through Edit.
    return unless select_value("SELECT COUNT(*) FROM users").to_i == 1

    execute <<~SQL
      INSERT INTO invoice_drafts
        (user_id, season_id, invoice_id, client_key, title, data, lock_version, created_at, updated_at)
      SELECT users.id, invoices.season_id, invoices.id,
        'existing-invoice-' || invoices.id,
        substr(invoices.number || ' · ' || invoices.recipient, 1, 180),
        '{}', 0, invoices.created_at, invoices.updated_at
      FROM invoices CROSS JOIN users
      WHERE invoices.finalized_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM invoice_drafts
          WHERE invoice_drafts.invoice_id = invoices.id AND invoice_drafts.user_id = users.id
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Existing workbenches may now contain user edits and must be retained"
  end
end
