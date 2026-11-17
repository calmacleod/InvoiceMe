module Horizon
  class Users < Resource
    PERMISSIONS = %i[user_type position super_user view_finance add_events team_affiliation event_affiliation venue_affiliation league_permission event_code_permission venue_permission].freeze
    operation :list, :get, [ "user" ], parameters: %i[user_id permission_id group_id user_type position event_code_affiliation team_affiliation venue_affiliation]
    operation :find, :get, [ "user", :id ]
    operation :find_permission, :get, [ "user", :id, :permission_id ]
    operation :create, :post, [ "user" ], parameters: PERMISSIONS + %i[first_name last_name email_address]
    operation :update_permission, :put, [ "user", :id, :permission_id ], parameters: PERMISSIONS
    operation :delete_permission, :delete, [ "user", :id, :permission_id ]
    operation :delete_many, :delete, [ "user" ], parameters: %i[permission_id]
  end
end
