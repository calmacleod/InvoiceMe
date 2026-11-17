module Horizon
  class Locations < Resource
    FIELDS = %i[name abbreviation address address_line_2 city region country phone phone_format get_mileage usable_for_events usable_for_meetings].freeze
    operation :list, :get, [ "location" ], parameters: %i[location_id location_type]
    operation :find, :get, [ "location", :id ]
    operation :create, :post, [ "location" ], parameters: FIELDS
    operation :update, :put, [ "location", :id ], parameters: FIELDS
    operation :deactivate, :delete, [ "location", :id ]
    operation :deactivate_many, :delete, [ "location" ], parameters: %i[location_id]
  end
end
