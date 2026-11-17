module Horizon
  class ContactGroups < Resource
    operation :list, :get, [ "contact_group" ], parameters: %i[contact_group_id]
    operation :find, :get, [ "contact_group", :id ]
    operation :create, :post, [ "contact_group" ], parameters: %i[name members shared_with edit_permission]
    operation :update, :put, [ "contact_group", :id ], parameters: %i[name shared_with edit_permission]
    operation :delete_many, :delete, [ "contact_group" ], parameters: %i[contact_group_id]
    operation :add_members, :post, [ "contact_group", :id ], parameters: %i[user_id]
    operation :remove_members, :delete, [ "contact_group", :id ], parameters: %i[user_id]
    operation :add_member, :post, [ "contact_group", :id, :user_id ]
    operation :remove_member, :delete, [ "contact_group", :id, :user_id ]
  end
end
