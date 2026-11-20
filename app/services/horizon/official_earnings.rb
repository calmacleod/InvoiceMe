module Horizon
  class OfficialEarnings
    TRAVEL_FIELDS = %w[travel_fee per_diem tolls other_fees].freeze

    def initialize(schedule, from:, through:)
      @schedule, @from, @through = schedule, from, through
    end

    def fetch
      events = SchedulePages.fetch(@schedule, start_date: @from.iso8601, end_date: @through.iso8601,
        event_type: "event", published: true, cancelled: false)
      rows = {}
      excluded = []
      event_ids = Set.new
      assignment_ids = Set.new
      events.each do |event|
        next if (event["event_type"] || event["type"]).to_s.casecmp?("meeting")

        event_id = event.fetch("event_id").to_s.strip
        date = Date.iso8601(event.fetch("event_start").to_s[0, 10])
        unless event_id.present? && event_ids.add?(event_id) && date.between?(@from, @through)
          raise Client::ResponseError, "Horizon returned a duplicate, invalid, or out-of-period game."
        end
        cancelled = event["cancelled"].to_s.strip.downcase
        next if event["vouchered"] == true
        unless event["vouchered"] == false && [ "", "no", "false", "0" ].include?(cancelled)
          excluded << (event["organization_event_id"].presence || event_id)
          next
        end
        assignments = event.fetch("assignment")
        unless assignments.is_a?(Array) && assignments.all?(Hash) && Integer(event.fetch("assignment_count")) == assignments.size
          raise Client::ResponseError, "Horizon returned incomplete game assignments."
        end
        assignments.each do |assignment|
          accepted = accepted_label(assignment["accepted"])
          next if accepted.casecmp?("declined") || (accepted.casecmp?("no") && assignment["decline_reason_given"].present?)

          assignment_id = assignment.fetch("assignment_id").to_s.strip
          user_id = assignment.fetch("user_id").to_s.strip
          name = [ assignment["last_name"], assignment["first_name"] ].filter_map { |part| part.to_s.squish.presence }.join(", ")
          unless user_id.present? && name.present? && assignment_id.present? && assignment_ids.add?(assignment_id)
            raise Client::ResponseError, "Horizon returned a missing or duplicate assignment identity."
          end
          row = (rows[user_id] ||= { name: name, assignments: [] })
          fee_cents = MoneyValue.cents(assignment.fetch("fee"))
          row[:assignments] << {
            "id" => assignment_id,
            "event_id" => event_id,
            "game" => (event["organization_event_id"].presence || event_id).to_s,
            "date" => date.iso8601,
            "position" => assignment["position"].to_s,
            "accepted" => accepted,
            "fee_cents" => fee_cents,
            "travel_ot_cents" => TRAVEL_FIELDS.sum { |field| MoneyValue.cents(assignment[field] || 0) },
            "deductions_cents" => deduction_cents(assignment["deductions"], fee_cents)
          }
        end
      end
      rows.each_value { |row| row[:assignments].sort_by! { |assignment| assignment.values_at("date", "game", "id") } }
      [ rows, excluded ]
    rescue KeyError, TypeError, ArgumentError
      raise Client::ResponseError, "Horizon returned an incomplete assignment or an invalid fee."
    end

    private

    def accepted_label(value)
      case value
      when true then "Yes"
      when false then "No"
      else value.to_s
      end
    end

    def deduction_cents(value, fee_cents)
      deduction = BigDecimal((value || 0).to_s)
      raise ArgumentError unless deduction.finite? && deduction >= 0

      (deduction * (deduction < 1 ? fee_cents : 100)).round
    end
  end
end
