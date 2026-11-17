module Horizon
  class Resource
    def initialize(client)
      @client = client
    end

    # IDs are positional, while documented query parameters are keyword arguments.
    def self.operation(name, verb, path, parameters: [], allow_extra: false)
      define_method(name) do |*ids, **params|
        raise ArgumentError, "Expected #{path.count { |part| part.is_a?(Symbol) }} path IDs" unless ids.length == path.count { |part| part.is_a?(Symbol) }
        unknown = params.keys - parameters
        raise ArgumentError, "Unknown Horizon parameters: #{unknown.join(', ')}" if unknown.any? && !allow_extra
        segments = path.map { |part| part.is_a?(Symbol) ? ids.shift : part }
        @client.request(verb, *segments, params: params)
      end
    end
  end
end
