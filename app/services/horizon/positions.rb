module Horizon
  class Positions < Resource
    operation :list, :get, [ "position" ], parameters: %i[position_id]
    operation :find, :get, [ "position", :id ]
    operation :deactivate, :delete, [ "position", :id ]
    operation :deactivate_many, :delete, [ "position" ], parameters: %i[position_id]
  end
end
