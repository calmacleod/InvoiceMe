require "net/http"
require "json"
class GoogleApi
  class Error < StandardError; end
  SCOPES = "openid email https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/spreadsheets".freeze
  def self.configured? = ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  def self.redirect_uri = "#{ENV.fetch('APP_URL', 'http://localhost:3000').delete_suffix('/')}/google/callback"
  def self.oauth_params
    { client_id: ENV.fetch("GOOGLE_CLIENT_ID"), client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"), redirect_uri: redirect_uri }
  end
  def self.token(params)
    response = Net::HTTP.start("oauth2.googleapis.com", 443, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
      request = Net::HTTP::Post.new("/token")
      request.set_form_data(params)
      http.request(request)
    end
    raise Error, "Google authorization failed. Reconnect the treasurer account." unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  end
  def initialize(connection = GoogleConnection.first)
    raise Error, "Connect your treasurer Google account in Settings first" unless connection
    @access_token = self.class.token(self.class.oauth_params.except(:redirect_uri).merge(refresh_token: connection.refresh_token, grant_type: "refresh_token")).fetch("access_token")
  end
  def request(method, url, json: nil, body: nil, content_type: "application/json", raw: false)
    uri = URI(url)
    raise Error, "Invalid Google endpoint" unless uri.scheme == "https" && %w[www.googleapis.com sheets.googleapis.com openidconnect.googleapis.com].include?(uri.host)
    request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
    request["Authorization"] = "Bearer #{@access_token}"
    request["Content-Type"] = content_type
    request.body = json ? JSON.generate(json) : body
    response = Net::HTTP.start(uri.host, 443, use_ssl: true, open_timeout: 10, read_timeout: 60) { |http| http.request(request) }
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Google returned HTTP #{response.code}. Check folder/sheet permissions and retry."
    end
    raw ? response.body : (response.body.blank? ? {} : JSON.parse(response.body))
  end
  def upload(name:, folder:, mime:, bytes:, key:, target_mime: mime)
    # appProperties recover a completed remote write after a dropped response or local failure.
    query = "trashed = false and '#{folder}' in parents and appProperties has { key='invoice_me' and value='#{key}' }"
    found = request(:get, "https://www.googleapis.com/drive/v3/files?#{URI.encode_www_form(q: query, fields: 'files(id)', pageSize: 2)}").fetch("files")
    raise Error, "Multiple matching Drive files found; check Drive before retrying" if found.size > 1
    return found.first.fetch("id") if found.any?
    boundary = "invoice_me_#{SecureRandom.hex(16)}"
    metadata = { name: name, mimeType: target_mime, parents: [ folder ], appProperties: { invoice_me: key } }
    multipart = "--#{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n#{JSON.generate(metadata)}\r\n--#{boundary}\r\nContent-Type: #{mime}\r\n\r\n".b + bytes.b + "\r\n--#{boundary}--\r\n".b
    request(:post, "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id", body: multipart, content_type: "multipart/related; boundary=#{boundary}").fetch("id")
  end
  def values(spreadsheet, range)
    request(:get, "https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheet}/values/#{ERB::Util.url_encode(range)}?valueRenderOption=UNFORMATTED_VALUE").fetch("values", [])
  end
  def write_values(spreadsheet, range, values)
    request(:put, "https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheet}/values/#{ERB::Util.url_encode(range)}?valueInputOption=RAW", json: { range: range, values: values })
  end
  def validate_destination(destination)
    %w[drive_folder_id pdf_folder_id].each do |field|
      next if destination[field].blank?
      file = request(:get, "https://www.googleapis.com/drive/v3/files/#{destination[field]}?fields=mimeType,capabilities(canAddChildren)")
      raise Error, "The configured #{field.humanize} is not a writable Google Drive folder" unless file["mimeType"] == "application/vnd.google-apps.folder" && file.dig("capabilities", "canAddChildren")
    end
    tab = "'#{destination.fetch('sheet_name').gsub("'", "''")}'"
    header_row = destination.fetch("ledger_start_row").to_i - 1
    headers = values(destination.fetch("spreadsheet_id"), "#{tab}!A#{header_row}:I#{header_row}").first.to_a.map { |h| h.to_s.downcase.gsub(/[^a-z]/, "") }
    expected = %w[invoicenumber datesent description contactname amountinvoiced amountreceived amountowed paymentmethod datedeposited]
    raise Error, "Master sheet columns A–I do not match the configured ledger layout. Check the tab name and first data row in Settings." unless headers == expected
  end
end
