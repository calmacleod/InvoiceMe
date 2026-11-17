require "test_helper"

class HorizonResourcesTest < ActiveSupport::TestCase
  test "every documented resource operation sends the expected method and path" do
    calls = []
    transport = Object.new
    transport.define_singleton_method(:request) { |verb, *path, params:| calls << [ verb, path, params ]; { "result" => [] } }
    cases = {
      Horizon::ContactGroups => { list: [ :get, %w[contact_group] ], find: [ :get, %w[contact_group id] ], create: [ :post, %w[contact_group] ], update: [ :put, %w[contact_group id] ], delete_many: [ :delete, %w[contact_group] ], add_members: [ :post, %w[contact_group id] ], remove_members: [ :delete, %w[contact_group id] ], add_member: [ :post, %w[contact_group id user] ], remove_member: [ :delete, %w[contact_group id user] ] },
      Horizon::CustomFields => { list: [ :get, %w[custom_field] ], find: [ :get, %w[custom_field id] ], find_answer: [ :get, %w[custom_field id user] ], delete_answers: [ :delete, %w[custom_field id] ], delete_answer: [ :delete, %w[custom_field id user] ], save_answer: [ :post, %w[custom_field id user] ] },
      Horizon::EventCodes => { list: [ :get, %w[event_code] ], find: [ :get, %w[event_code id] ], create: [ :post, %w[event_code] ], update: [ :put, %w[event_code id] ], deactivate: [ :delete, %w[event_code id] ], deactivate_many: [ :delete, %w[event_code] ] },
      Horizon::Leagues => { list: [ :get, %w[league] ], find: [ :get, %w[league id] ], create: [ :post, %w[league] ], update: [ :put, %w[league id] ], deactivate: [ :delete, %w[league id] ], deactivate_many: [ :delete, %w[league] ] },
      Horizon::Locations => { list: [ :get, %w[location] ], find: [ :get, %w[location id] ], create: [ :post, %w[location] ], update: [ :put, %w[location id] ], deactivate: [ :delete, %w[location id] ], deactivate_many: [ :delete, %w[location] ] },
      Horizon::ManualRanks => { list: [ :get, %w[manual_rank] ], find: [ :get, %w[manual_rank id] ], update: [ :put, %w[manual_rank id] ] },
      Horizon::PayrollAdjustments => { list: [ :get, %w[payroll_adjustment] ], find: [ :get, %w[payroll_adjustment id] ], create: [ :post, %w[payroll_adjustment] ], update: [ :put, %w[payroll_adjustment id] ], update_many: [ :put, %w[payroll_adjustment] ], delete: [ :delete, %w[payroll_adjustment id] ], delete_many: [ :delete, %w[payroll_adjustment] ] },
      Horizon::Positions => { list: [ :get, %w[position] ], find: [ :get, %w[position id] ], deactivate: [ :delete, %w[position id] ], deactivate_many: [ :delete, %w[position] ] },
      Horizon::Schedule => { list: [ :get, %w[schedule] ], find: [ :get, %w[schedule id] ], create: [ :post, %w[schedule] ], update: [ :put, %w[schedule id] ], cancel_many: [ :delete, %w[schedule] ], remove: [ :delete, %w[schedule id] ] },
      Horizon::Teams => { list: [ :get, %w[team] ], find: [ :get, %w[team id] ], create: [ :post, %w[team] ], update: [ :put, %w[team id] ], deactivate: [ :delete, %w[team id] ], deactivate_many: [ :delete, %w[team] ] },
      Horizon::Users => { list: [ :get, %w[user] ], find: [ :get, %w[user id] ], find_permission: [ :get, %w[user id user] ], create: [ :post, %w[user] ], update_permission: [ :put, %w[user id user] ], delete_permission: [ :delete, %w[user id user] ], delete_many: [ :delete, %w[user] ] }
    }
    cases.each do |klass, operations|
      resource = klass.new(transport)
      operations.each do |name, (verb, path)|
        resource.public_send(name, *path.drop(1))
        assert_equal [ verb, path, {} ], calls.last, "#{klass}##{name}"
      end
    end
  end

  test "parameters and false values pass through and invalid names and missing ids fail locally" do
    calls = []
    transport = Object.new
    transport.define_singleton_method(:request) { |*args, **kwargs| calls << [ args, kwargs ] }
    Horizon::Schedule.new(transport).list(start_date: "2031-01-01", team_id: [ "fictional" ], cancelled: false)
    assert_equal [ [ :get, "schedule" ], { params: { start_date: "2031-01-01", team_id: [ "fictional" ], cancelled: false } } ], calls.last
    Horizon::ContactGroups.new(transport).add_members("fictional", user_id: [ "a", "b" ])
    assert_equal [ [ :post, "contact_group", "fictional" ], { params: { user_id: [ "a", "b" ] } } ], calls.last
    assert_raises(ArgumentError) { Horizon::Schedule.new(transport).list(start_dat: "2031-01-01") }
    assert_raises(ArgumentError) { Horizon::Teams.new(transport).find }
  end
end
