module Horizon
  class EventCodes < Resource
    operation :list, :get, [ "event_code" ], parameters: %i[event_code_id]
    operation :find, :get, [ "event_code", :id ]
    operation :create, :post, [ "event_code" ], parameters: %i[name]
    operation :update, :put, [ "event_code", :id ], parameters: %i[name]
    operation :deactivate, :delete, [ "event_code", :id ]
    operation :deactivate_many, :delete, [ "event_code" ], parameters: %i[event_code_id]
  end
end
