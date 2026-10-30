class FakeGoogle
  attr_reader :uploads, :writes, :upload_calls
  attr_accessor :fail_write, :write_error, :upload_error, :fail_mime, :after_write_error

  def initialize
    @uploads, @writes, @upload_calls, @row = [], [], [], nil
  end

  def upload(**attrs)
    @upload_calls << attrs
    raise @upload_error if @upload_error && (!@fail_mime || @fail_mime == attrs[:mime])
    @uploads << attrs
    "file-#{@uploads.size}"
  end

  def validate_destination(_) = true

  def values(_, _range)
    @row ? [ @row ] : []
  end

  def write_values(_, range, values)
    raise GoogleApi::Error, "Network failed" if @fail_write
    raise @write_error if @write_error
    @writes << [ range, values ]
    @row = values.first
    raise @after_write_error if @after_write_error
  end
end
