module Horizon
  class PayrollAdjustments < Resource
    operation :list, :get, [ "payroll_adjustment" ], parameters: %i[payroll_adjustment_id user_id adjuster_id start_date end_date]
    operation :find, :get, [ "payroll_adjustment", :id ]
    operation :create, :post, [ "payroll_adjustment" ], parameters: %i[user_id reason operation amount date_applied]
    operation :update, :put, [ "payroll_adjustment", :id ], parameters: %i[reason operation amount date_applied]
    # The reference labels the bulk ID as a path parameter but has no path placeholder.
    operation :update_many, :put, [ "payroll_adjustment" ], parameters: %i[payroll_adjustment_id reason operation amount date_applied]
    operation :delete, :delete, [ "payroll_adjustment", :id ]
    operation :delete_many, :delete, [ "payroll_adjustment" ], parameters: %i[payroll_adjustment_id]
  end
end
