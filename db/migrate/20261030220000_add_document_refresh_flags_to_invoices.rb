class AddDocumentRefreshFlagsToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :google_doc_dirty, :boolean, default: false, null: false
    add_column :invoices, :google_pdf_dirty, :boolean, default: false, null: false
  end
end
