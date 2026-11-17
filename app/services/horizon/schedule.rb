module Horizon
  class Schedule < Resource
    FILTERS = %i[start_date end_date event_id cancelled score_reported published league_id event_code_id home_team_id visiting_team_id team_id event_type user_id sort_order].freeze
    FIELDS = %i[event_date start_time end_time league_id event_code_id home_team_id visiting_team_id location_id meeting_title personnel_needed max_attendees vouchered manual_id].freeze
    operation :list, :get, [ "schedule" ], parameters: FILTERS
    operation :find, :get, [ "schedule", :id ]
    operation :create, :post, [ "schedule" ], parameters: FIELDS + %i[event_type]
    operation :update, :put, [ "schedule", :id ], parameters: FIELDS
    operation :cancel_many, :delete, [ "schedule" ], parameters: %i[event_id operation]
    operation :remove, :delete, [ "schedule", :id ], parameters: %i[operation]
  end
end
