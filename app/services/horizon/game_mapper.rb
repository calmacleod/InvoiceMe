module Horizon
  class GameMapper
    FEES = %w[fee travel_fee per_diem tolls other_fees].freeze

    def self.call(event)
      id = event.fetch("event_id").to_s.strip
      raise ArgumentError, "Horizon returned a game without an ID" if id.blank?
      start = DateTime.parse(event.fetch("event_start"))
      assignments = event.fetch("assignment")
      raise ArgumentError, "Horizon returned invalid assignments" unless assignments.is_a?(Array) && event["assignment_count"].to_i == assignments.size
      officials = assignments.map do |assignment|
        raise ArgumentError, "Horizon returned an assignment without a fee" if assignment["fee"].nil?
        name = [ assignment["last_name"].presence, assignment["first_name"].presence ].compact.join(", ")
        amount = FEES.sum { |field| MoneyValue.cents((assignment[field] || 0).to_s) }
        { "name" => name.presence || "Unassigned", "position" => assignment["position"], "fee_cents" => amount }
      end
      {
        "external_id" => id, "horizon_cancelled" => event["cancelled"]&.to_s, "date" => start.to_date.iso8601, "time" => start.strftime("%-I:%M%P"),
        "code" => name_of(event["event_code"]), "home_team" => name_of(event["home_team"]),
        "away_team" => name_of(event["visiting_team"]), "location" => name_of(event["location"]),
        "officials" => officials, "fees_cents" => officials.sum { |official| official.fetch("fee_cents") }
      }
    rescue KeyError, Date::Error, TypeError
      raise ArgumentError, "Horizon returned an incomplete game"
    end

    def self.name_of(value)
      value = value.first if value.is_a?(Array)
      value.is_a?(Hash) ? value["name"] : nil
    end
    private_class_method :name_of
  end
end
