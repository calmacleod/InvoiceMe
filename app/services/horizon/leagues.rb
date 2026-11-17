module Horizon
  class Leagues < Resource
    operation :list, :get, [ "league" ], parameters: %i[league_id]
    operation :find, :get, [ "league", :id ]
    operation :create, :post, [ "league" ], parameters: %i[name abbreviation incident_report]
    operation :update, :put, [ "league", :id ], parameters: %i[name abbreviation incident_report]
    operation :deactivate, :delete, [ "league", :id ]
    operation :deactivate_many, :delete, [ "league" ], parameters: %i[league_id]
  end
end
