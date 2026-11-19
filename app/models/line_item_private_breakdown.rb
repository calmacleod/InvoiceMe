class LineItemPrivateBreakdown < ApplicationRecord
  belongs_to :line_item
  belongs_to :user
  serialize :data, coder: JSON, type: Hash

  def self.valid_data?(value)
    value.is_a?(Hash) && (value.keys - %w[notes entries]).empty? &&
      value["notes"].is_a?(String) && value["notes"].length <= 10_000 &&
      value["entries"].is_a?(Array) && value["entries"].size <= 200 &&
      value["entries"].all? do |entry|
        entry.is_a?(Hash) && (entry.keys - %w[key description amount]).empty? &&
          %w[key description amount].all? { |field| entry[field].is_a?(String) && entry[field].length <= 1_000 }
      end
  end

  validate { errors.add(:data, "has an invalid format") unless self.class.valid_data?(data) }
end
