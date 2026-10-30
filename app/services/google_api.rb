require "net/http"
require "json"
class GoogleApi
  class Error < StandardError; end
  class TransientError < Error; end
  RETRYABLE_STATUSES = %w[429 500 502 503 504].freeze
  RATE_LIMIT_REASONS = %w[rateLimitExceeded userRateLimitExceeded].freeze
  NETWORK_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError ].freeze
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
    raise TransientError, "Google authorization is temporarily unavailable. The export can be retried." if transient_response?(response)
    raise Error, "Google authorization failed. Reconnect the treasurer account." unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue *NETWORK_ERRORS
    raise TransientError, "The connection to Google authorization was interrupted. The export can be retried."
  end
  def initialize(connection = GoogleConnection.first)
    raise Error, "Connect your treasurer Google account in Settings first" unless connection
    @access_token = self.class.token(self.class.oauth_params.except(:redirect_uri).merge(refresh_token: connection.refresh_token, grant_type: "refresh_token")).fetch("access_token")
  end
  def request(method, url, json: nil, body: nil, content_type: "application/json", raw: false, operation: "accessing Google")
    uri = URI(url)
    raise Error, "Invalid Google endpoint" unless uri.scheme == "https" && %w[www.googleapis.com sheets.googleapis.com openidconnect.googleapis.com].include?(uri.host)
    request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
    request["Authorization"] = "Bearer #{@access_token}"
    request["Content-Type"] = content_type
    request.body = json ? JSON.generate(json) : body
    response = Net::HTTP.start(uri.host, 443, use_ssl: true, open_timeout: 10, read_timeout: 60) { |http| http.request(request) }
    unless response.is_a?(Net::HTTPSuccess)
      error_class = self.class.transient_response?(response) ? TransientError : Error
      raise error_class, error_message(response, operation)
    end
    raw ? response.body : (response.body.blank? ? {} : JSON.parse(response.body))
  rescue *NETWORK_ERRORS
    raise TransientError, "The connection to Google was interrupted while #{operation}. The export can be retried."
  end
  def upload(name:, folder:, mime:, bytes:, key:, target_mime: mime, file_id: nil, replace: false)
    # appProperties recover a completed remote write after a dropped response or local failure.
    unless file_id
      query = "trashed = false and '#{folder}' in parents and appProperties has { key='invoice_me' and value='#{key}' }"
      found = request(:get, "https://www.googleapis.com/drive/v3/files?#{URI.encode_www_form(q: query, fields: 'files(id)', pageSize: 2)}", operation: "finding an existing Drive export").fetch("files")
      raise Error, "Multiple matching Drive files found; check Drive before retrying" if found.size > 1
      file_id = found.first&.fetch("id")
    end
    return file_id if file_id && !replace
    boundary = "invoice_me_#{SecureRandom.hex(16)}"
    metadata = { name: name, mimeType: target_mime, appProperties: { invoice_me: key } }
    metadata[:parents] = [ folder ] unless file_id
    multipart = "--#{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n#{JSON.generate(metadata)}\r\n--#{boundary}\r\nContent-Type: #{mime}\r\n\r\n".b + bytes.b + "\r\n--#{boundary}--\r\n".b
    operation = target_mime == "application/vnd.google-apps.document" ? "creating the Google Doc" : "uploading the PDF"
    operation = target_mime == "application/vnd.google-apps.document" ? "updating the Google Doc" : "updating the PDF" if file_id
    path = file_id ? "files/#{ERB::Util.url_encode(file_id)}" : "files"
    request(file_id ? :patch : :post, "https://www.googleapis.com/upload/drive/v3/#{path}?uploadType=multipart&fields=id", body: multipart, content_type: "multipart/related; boundary=#{boundary}", operation: operation).fetch("id")
  end
  def values(spreadsheet, range)
    request(:get, "https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheet}/values/#{ERB::Util.url_encode(range)}?valueRenderOption=UNFORMATTED_VALUE", operation: "reading the Google Sheets ledger").fetch("values", [])
  end
  def write_values(spreadsheet, range, values)
    request(:put, "https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheet}/values/#{ERB::Util.url_encode(range)}?valueInputOption=RAW", json: { range: range, values: values }, operation: "updating the Google Sheets ledger")
  end
  def sheet_metadata(spreadsheet, title)
    fields = "sheets(properties(sheetId,title,gridProperties),tables)"
    result = request(:get, "https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheet}?#{URI.encode_www_form(fields: fields)}", operation: "checking the ledger table")
    result.fetch("sheets").find { |sheet| sheet.dig("properties", "title") == title } || raise(Error, "The configured ledger tab was not found. Check Settings.")
  end
  def ledger_cells(spreadsheet, range)
    query = { ranges: range, includeGridData: true, fields: "sheets(data(rowData(values(userEnteredValue,effectiveValue,userEnteredFormat(numberFormat),dataValidation,chipRuns))))" }
    result = request(:get, "https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheet}?#{URI.encode_www_form(query)}", operation: "checking the target ledger row")
    result.fetch("sheets").first.fetch("data").first.fetch("rowData", []).first&.fetch("values", []) || []
  end
  def batch_update(spreadsheet, requests)
    request(:post, "https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheet}:batchUpdate", json: { requests: requests }, operation: "updating the Google Sheets ledger")
  end
  def validate_destination(destination)
    %w[drive_folder_id pdf_folder_id].each do |field|
      next if destination[field].blank?
      file = request(:get, "https://www.googleapis.com/drive/v3/files/#{destination[field]}?fields=mimeType,capabilities(canAddChildren)", operation: "checking the Drive folder")
      raise Error, "The configured #{field.humanize} is not a writable Google Drive folder" unless file["mimeType"] == "application/vnd.google-apps.folder" && file.dig("capabilities", "canAddChildren")
    end
    tab = "'#{destination.fetch('sheet_name').gsub("'", "''")}'"
    header_row = destination.fetch("ledger_start_row").to_i - 1
    headers = values(destination.fetch("spreadsheet_id"), "#{tab}!A#{header_row}:I#{header_row}").first.to_a.map { |h| h.to_s.downcase.gsub(/[^a-z]/, "") }
    expected = %w[invoicenumber datesent description contactname amountinvoiced amountreceived amountowed paymentmethod datedeposited]
    raise Error, "Master sheet columns A–I do not match the configured ledger layout. Check the tab name and first data row in Settings." unless headers == expected
  end

  private

  def error_message(response, operation)
    reason = self.class.error_reason(response)
    detail = " (#{reason})" if reason
    guidance = case response.code
    when "401" then "Reconnect the treasurer Google account in Settings."
    when "403" then self.class.transient_response?(response) ? "Google is limiting requests. The export can be retried." : "Check folder/sheet permissions and that the Drive and Sheets APIs are enabled."
    when "404" then "Check the folder and spreadsheet IDs in Settings and their sharing permissions."
    when "429" then "Google is limiting requests. Wait briefly and retry syncing."
    when "500", "502", "503", "504" then "Google could not process the request. Try syncing again shortly."
    else "Check the Google configuration in Settings and retry."
    end
    "Google returned HTTP #{response.code} while #{operation}#{detail}. #{guidance}"
  end

  def self.transient_response?(response)
    RETRYABLE_STATUSES.include?(response.code) || (response.code == "403" && RATE_LIMIT_REASONS.include?(error_reason(response)))
  end

  def self.error_reason(response)
    # Retain Google's diagnostic code, not its free-form response (which can
    # contain invoice content, IDs, or other private request data).
    payload = JSON.parse(response.body.to_s)
    errors = payload["error"]["errors"] if payload.is_a?(Hash) && payload["error"].is_a?(Hash)
    reason = errors.first["reason"] if errors.is_a?(Array) && errors.first.is_a?(Hash)
    reason if reason.is_a?(String) && reason.match?(/\A[a-zA-Z][a-zA-Z0-9_]{0,79}\z/)
  rescue JSON::ParserError
    nil
  end
end
