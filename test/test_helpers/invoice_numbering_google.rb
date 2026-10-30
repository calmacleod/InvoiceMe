require_relative "fake_google"

module InvoiceNumberingGoogle
  extend ActiveSupport::Concern

  included do
    setup do
      seasons(:current).update!(spreadsheet_id: "fictional-ledger")
      @numbering_api = FakeGoogle.new
      @numbering_api.rows[2] = [ "Invoice Number" ]
      @numbering_api.rows[3] = [ "2026_04_FictionalClub" ]
      @original_google_new = GoogleApi.method(:new)
      api = @numbering_api
      GoogleApi.define_singleton_method(:new) { |*| api }
    end

    teardown do
      GoogleApi.define_singleton_method(:new, @original_google_new)
    end
  end
end
