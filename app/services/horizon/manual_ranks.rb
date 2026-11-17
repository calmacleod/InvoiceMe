module Horizon
  class ManualRanks < Resource
    operation :list, :get, [ "manual_rank" ], parameters: %i[user_id]
    operation :find, :get, [ "manual_rank", :user_id ]
    # Horizon does not document the rank fields for this operation.
    operation :update, :put, [ "manual_rank", :user_id ], allow_extra: true
  end
end
