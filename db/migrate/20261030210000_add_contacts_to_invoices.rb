class AddContactsToInvoices < ActiveRecord::Migration[8.1]
  def change
    # NULL preserves the legacy contact until an invoice is edited. An explicit
    # empty array means its contacts were intentionally removed.
    add_column :invoices, :contacts, :json
  end
end
