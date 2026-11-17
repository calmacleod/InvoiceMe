module Horizon
  class Teams < Resource
    FIELDS = %i[name abbreviation usable_as_home_team usable_as_visiting_team].freeze
    operation :list, :get, [ "team" ], parameters: %i[team_id team_type]
    operation :find, :get, [ "team", :id ]
    operation :create, :post, [ "team" ], parameters: FIELDS
    operation :update, :put, [ "team", :id ], parameters: FIELDS
    operation :deactivate, :delete, [ "team", :id ]
    operation :deactivate_many, :delete, [ "team" ], parameters: %i[team_id]
  end
end
