class MoneyValue
  def self.cents(value)
    text = value.to_s.strip.delete("$,")
    raise ArgumentError, "Invalid money amount: #{value}" unless text.match?(/\A\d+(?:\.\d{1,2})?\z/)
    (BigDecimal(text) * 100).to_i
  end
end
