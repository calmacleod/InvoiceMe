require "csv"
require "date"
class GameImport
  FIELDS = %w[external_id code date time home_team away_team location officials fees].freeze
  REQUIRED = %w[external_id date].freeze
  ALIASES = {
    "external_id" => [ "game", "game #", "game number", "game id", "game id#", "game no", "event id" ],
    "code" => [ "game code", "code", "billing code" ], "date" => [ "date", "game date" ],
    "time" => [ "time", "game time" ], "home_team" => [ "home", "home team" ],
    "away_team" => [ "away", "away team", "visitor", "visiting team" ],
    "location" => [ "location", "venue", "site", "field" ], "officials" => [ "officials", "official", "official name", "name" ],
    "fees" => [ "total paid", "amount paid", "total fees", "game fee", "fee", "fees", "pay", "amount" ]
  }.freeze
  attr_reader :headers, :rows, :errors, :games
  def initialize(headers, rows, mapping, date_format: "%m/%d/%Y")
    @headers, @rows, @mapping, @date_format = headers, rows, mapping, date_format
    @errors, @games = [], {}
  end
  def self.read(upload)
    raise ArgumentError, "Choose a CSV or XLSX file under 10 MB" unless upload && upload.size <= 10.megabytes
    if File.extname(upload.original_filename).downcase == ".xlsx"
      sheet = Roo::Excelx.new(upload.tempfile.path)
      raise ArgumentError, "Limit imports to 20,000 rows and 100 columns" if sheet.last_row.to_i > 20_001 || sheet.last_column.to_i > 100
      data = sheet.to_a
    else
      raw = upload.read.force_encoding("UTF-8").delete_prefix("\uFEFF")
      raise ArgumentError, "Use a UTF-8 CSV export" unless raw.valid_encoding?
      data = CSV.parse(raw, col_sep: raw.lines.first.to_s.count("\t") > raw.lines.first.to_s.count(",") ? "\t" : ",")
    end
    raise ArgumentError, "Limit imports to 20,000 rows and 100 columns" if data.size > 20_001 || data.first.to_a.size > 100
    headers = data.shift.to_a.map { |v| v.to_s.strip }
    raise ArgumentError, "The first row must contain unique column headings" if headers.empty? || headers.uniq.size != headers.size
    rows = data.reject { |r| r.all?(&:blank?) }.map { |r| r.map { |v| v.is_a?(Date) ? v.iso8601 : v.to_s } }
    if headers.first == "Game ID#" && headers.last == "Officials/Positions"
      normalize_horizon(headers, rows)
    else
      [ headers, rows, {} ]
    end
  end
  def self.normalize_horizon(headers, rows)
    meetings, games = rows.partition { |row| row.first == "MEETING" }
    games.each_with_index do |row, index|
      unless row.first.to_s.match?(/\A\d+\z/) && (row.drop(10).all?(&:blank?) || (row.size - 10) % 3 == 0)
        raise ArgumentError, "Horizon row #{index + 2} has an unexpected game number or incomplete official/position/fee group"
      end
    end
    count = games.map { |row| (row.size - 10) / 3 }.max.to_i
    normalized = headers.first(10) + (1..count).flat_map { |n| [ "Official #{n}", "Position #{n}", "Fee #{n}" ] }
    raise ArgumentError, "Limit imports to 100 columns" if normalized.size > 100
    [ normalized, games.map { |row| row.first(normalized.size).fill("", row.size...normalized.size) }, { "format" => "horizon_master_fees", "skipped_meetings" => meetings.size } ]
  end
  def self.guess(headers)
    mapping = FIELDS.to_h { |field| [ field, headers.find { |h| ALIASES.fetch(field).include?(h.downcase.strip) }.to_s ] }
    positions = headers.grep(/\AOfficial \d+\z/)
    if positions.any?
      mapping["official_columns"] = positions.each_with_index.to_h do |column, index|
        n = column.split.last
        [ index.to_s, { "name" => column, "position" => "Position #{n}", "amount" => "Fee #{n}" } ]
      end
    end
    mapping
  end
  def parse
    REQUIRED.each { |f| errors << "Map the #{f.humanize} column" if @mapping[f].blank? || !headers.include?(@mapping[f]) }
    return self if errors.any?
    seen = {}
    rows.each_with_index do |row, index|
      begin
        raise ArgumentError, "Duplicate row; remove the repeated entry to avoid counting fees twice" if seen[row]
        seen[row] = true
        value = ->(field) { row[headers.index(@mapping[field])] if headers.include?(@mapping[field]) }
        id = value.call("external_id").to_s.strip
        raise ArgumentError, "Missing game number" if id.blank?
        date_text = value.call("date").to_s.strip
        date = date_text.match?(/\A\d{4}-\d{2}-\d{2}\z/) ? Date.iso8601(date_text) : Date.strptime(date_text, @date_format)
        game = { external_id: id, code: value.call("code"), date: date, time: value.call("time"), home_team: value.call("home_team"), away_team: value.call("away_team"), location: value.call("location") }
        # Rows may be one per game or one per official. Repeated imports replace the aggregate.
        aggregate = @games[id] ||= game.merge(officials: [], fees_cents: 0, source: [])
        raise ArgumentError, "Game #{id} has inconsistent dates" unless aggregate[:date] == date
        fee = value.call("fees").presence
        name = value.call("officials").to_s.strip
        names = name.split(/[;|\n]+/).map(&:strip).reject(&:blank?)
        names.each { |n| aggregate[:officials] << { "name" => n, "fee_cents" => fee && names.size == 1 ? MoneyValue.cents(fee) : nil } }
        columns = @mapping.fetch("official_columns", {})
        columns = columns.values if columns.is_a?(Hash)
        assignment_total = 0
        columns.each do |pair|
          next if pair["name"].blank? || !headers.include?(pair["name"])
          official_name = row[headers.index(pair["name"])].to_s.strip
          amount = headers.include?(pair["amount"]) ? row[headers.index(pair["amount"])].presence : nil
          position = headers.include?(pair["position"]) ? row[headers.index(pair["position"])].presence : nil
          next if official_name.blank? && amount.blank? && position.blank?
          cents = amount ? MoneyValue.cents(amount) : nil
          assignment_total += cents.to_i
          aggregate[:officials] << { "name" => official_name.presence || "Unassigned", "fee_cents" => cents, "position" => position || pair["name"] }
        end
        aggregate[:fees_cents] += fee ? MoneyValue.cents(fee) : assignment_total
        aggregate[:source] << headers.zip(row).to_h
      rescue ArgumentError, TypeError => e
        errors << "Row #{index + 2}: #{e.message}"
      end
    end
    errors << "No games found" if @games.empty? && errors.empty?
    self
  end
  def commit!(season)
    raise ArgumentError, errors.join("; ") if errors.any?
    Game.transaction do
      games.each_value do |attributes|
        record = season.games.find_or_initialize_by(external_id: attributes[:external_id])
        record.update!(attributes)
      end
      season.update!(import_mapping: @mapping)
    end
  end
end
