module InvoiceContacts
  FIELDS = %w[name email].freeze

  def self.valid_format?(contacts)
    contacts.is_a?(Array) && contacts.all? do |contact|
      contact.is_a?(Hash) && (contact.keys - FIELDS).empty? &&
        FIELDS.all? { |field| contact[field].is_a?(String) } &&
        contact["name"].length <= 200 && contact["email"].length <= 250
    end
  end

  def self.from_legacy(value)
    return [] if value.blank?

    address = Mail::Address.new(value)
    if URI::MailTo::EMAIL_REGEXP.match?(address.address.to_s)
      [ { "name" => address.display_name.to_s, "email" => address.address.downcase } ]
    else
      [ { "name" => value.include?("@") ? "" : value.strip, "email" => "" } ]
    end
  rescue Mail::Field::ParseError
    # Keep the original in the legacy column, but never print an unparsed email.
    [ { "name" => value.include?("@") ? "" : value.strip, "email" => "" } ]
  end
end
