class FakeGoogle
  attr_reader :uploads, :writes, :upload_calls, :batches
  attr_accessor :fail_write, :write_error, :upload_error, :fail_mime, :after_write_error
  attr_accessor :rows, :cells, :sheet

  def initialize
    @uploads, @writes, @upload_calls, @batches = [], [], [], []
    @rows, @cells = {}, {}
    @sheet = { "properties" => { "sheetId" => 123, "title" => "2026 invoices", "gridProperties" => { "rowCount" => 100 } } }
  end

  def upload(**attrs)
    @upload_calls << attrs
    raise @upload_error if @upload_error && (!@fail_mime || @fail_mime == attrs[:mime])
    @uploads << attrs
    attrs[:file_id] || "file-#{@uploads.size}"
  end

  def validate_destination(_) = true

  def sheet_metadata(_, _) = @sheet

  def values(_, range)
    start, finish = range.match(/![A-Z]+(\d+):[A-Z]+(\d*)/).captures
    start = start.to_i
    finish = finish.present? ? finish.to_i : [ start, @rows.keys.max || start ].max
    result = (start..finish).map { |row| @rows.fetch(row, []).dup }
    result.pop while result.last&.all?(&:nil?)
    result
  end

  def ledger_cells(_, range)
    row = range.match(/![A-Z]+(\d+)/)[1].to_i
    (0...12).map do |index|
      cell = @cells.fetch(row, [])[index].to_h.deep_dup
      value = @rows.fetch(row, [])[index]
      cell["userEnteredValue"] ||= extended_value(value) unless value.nil?
      cell["effectiveValue"] = extended_value(value) unless value.nil?
      cell
    end
  end

  def batch_update(_, requests)
    check_write_error!
    @batches << requests.deep_dup
    requests.each do |request|
      update = request.fetch(:updateCells)
      row = update.fetch(:range).fetch(:startRowIndex) + 1
      data = update.fetch(:rows).first.fetch(:values)
      @cells[row] ||= []
      @rows[row] ||= []
      data.each_with_index do |cell, index|
        @cells[row][index] ||= {}
        entered = cell[:userEnteredValue]&.deep_stringify_keys
        entered ? @cells[row][index]["userEnteredValue"] = entered : @cells[row][index].delete("userEnteredValue")
        @rows[row][index] = entered&.values&.first
      end
      if @cells[row].dig(6, "userEnteredValue", "formulaValue")&.match?(/\A=E\d+-F\d+\z/)
        @rows[row][6] = @rows[row][4].to_f - @rows[row][5].to_f
      end
      title = @sheet.fetch("properties").fetch("title").gsub("'", "''")
      @writes << [ "'#{title}'!A#{row}:I#{row}", [ @rows[row].first(9).dup ] ]
    end
    raise @after_write_error if @after_write_error
  end

  def write_values(_, range, values)
    check_write_error!
    @writes << [ range, values ]
    row = range[/![A-Z]+(\d+)/, 1].to_i
    @rows[row.zero? ? 3 : row] = values.first
    raise @after_write_error if @after_write_error
  end

  private

  def extended_value(value)
    value.is_a?(Numeric) ? { "numberValue" => value } : { "stringValue" => value.to_s }
  end

  def check_write_error!
    raise GoogleApi::Error, "Network failed" if @fail_write
    raise @write_error if @write_error
  end
end
