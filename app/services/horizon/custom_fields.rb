module Horizon
  class CustomFields < Resource
    operation :list, :get, [ "custom_field" ], parameters: %i[custom_field_id user_id]
    operation :find, :get, [ "custom_field", :id ], parameters: %i[user_id]
    operation :find_answer, :get, [ "custom_field", :id, :user_id ]
    operation :delete_answers, :delete, [ "custom_field", :id ]
    operation :delete_answer, :delete, [ "custom_field", :id, :user_id ]
    operation :save_answer, :post, [ "custom_field", :id, :user_id ], parameters: %i[answer]
  end
end
