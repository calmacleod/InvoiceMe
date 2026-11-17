require "net/http"
require "json"

module Horizon
  class Client
    BASE_URI = URI("https://api-2445581139242.apicast.io/api/v1").freeze
    METHODS = %w[GET POST PUT DELETE].freeze
    NETWORK_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError ].freeze

    class Error < StandardError
      attr_reader :status

      def initialize(message, status: nil)
        @status = status
        super(message)
      end
    end
    class ConfigurationError < Error; end
    class AuthenticationError < Error; end
    class RateLimitError < Error; end
    class TransientError < Error; end
    class ResponseError < Error; end

    def self.configured?
      ENV["HORIZON_APP_ID"].present? && ENV["HORIZON_APP_KEY"].present?
    end

    def initialize(app_id: ENV["HORIZON_APP_ID"], app_key: ENV["HORIZON_APP_KEY"], access_token: nil)
      raise ConfigurationError, "Horizon application ID and key are required" if app_id.blank? || app_key.blank?

      @app_id, @app_key, @access_token = app_id, app_key, access_token
    end

    def request_code(scope:, callback_uri:)
      request(:post, "oauth2", "requestCode", params: { scope: scope, callback_uri: callback_uri }, authenticated: false)
    end

    def request_token(authorization_code:)
      request(:post, "oauth2", "requestToken", params: { authorization_code: authorization_code }, authenticated: false)
    end

    # Segments are encoded separately; callers cannot redirect credentials to another host.
    # The returned hash retains Horizon's result and pagination metadata.
    def request(method, *segments, params: {}, authenticated: true)
      verb = method.to_s.upcase
      raise ArgumentError, "Unsupported Horizon request method" unless METHODS.include?(verb)
      raise ArgumentError, "Horizon endpoint segments are required" if segments.empty? || segments.any? { |segment| segment.to_s.empty? || %w[. ..].include?(segment.to_s) }
      raise ArgumentError, "Horizon parameters must be a hash" unless params.is_a?(Hash)
      raise ConfigurationError, "Horizon access token is required" if authenticated && @access_token.blank?

      path = segments.map { |segment| URI.encode_www_form_component(segment.to_s).gsub("+", "%20") }.join("/")
      uri = BASE_URI.dup
      uri.path = "#{BASE_URI.path}/#{path}"
      http_request = Net::HTTPGenericRequest.new(verb, true, true, uri)
      http_request["app_id"] = @app_id
      http_request["app_key"] = @app_key
      http_request["access_token"] = @access_token if authenticated
      http_request["Accept"] = "application/json"
      http_request["Content-Type"] = "application/json"
      http_request.body = JSON.generate(params) unless params.empty?
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60, max_retries: 0) { |http| http.request(http_request) }
      handle_response(response)
    rescue *NETWORK_ERRORS
      raise TransientError, "The connection to Horizon was interrupted"
    end

    private

    def handle_response(response)
      code = response.code.to_i
      unless response.is_a?(Net::HTTPSuccess)
        error_class = case code
        when 401, 403 then AuthenticationError
        when 429 then RateLimitError
        when 500..599 then TransientError
        else Error
        end
        raise error_class.new("Horizon returned HTTP #{code}", status: code)
      end

      payload = JSON.parse(response.body.to_s)
      raise ResponseError, "Horizon returned an unexpected response" unless payload.is_a?(Hash)
      # Some API failures may be represented in the JSON envelope even with HTTP 200.
      if payload["error"].present? || (payload["status"].is_a?(Integer) && payload["status"] >= 400)
        raise Error.new("Horizon returned an error response", status: payload["status"])
      end
      payload
    rescue JSON::ParserError
      raise ResponseError, "Horizon returned invalid JSON"
    end
  end
end
