class HorizonController < ApplicationController
  before_action :need_season
  rescue_from Horizon::Client::Error, with: :horizon_error

  def connect
    raise Horizon::Client::Error, "Disconnect the existing Horizon connection before connecting again." if HorizonConnection.exists?
    session.delete(:horizon_oauth_state)
    session.delete(:horizon_oauth_started_at)
    state = SecureRandom.hex(32)
    callback = "#{ENV.fetch('APP_URL', 'http://localhost:3000').delete_suffix('/')}/horizon/callback/#{state}"
    response = Horizon::Client.new.request_code(scope: [ "read_organization" ], callback_uri: callback)
    uri = URI.parse(response.fetch("login_uri").to_s)
    unless uri.is_a?(URI::HTTPS) && uri.userinfo.nil? && (uri.host == "horizonwebref.com" || uri.host&.end_with?(".horizonwebref.com"))
      raise Horizon::Client::ResponseError, "Horizon returned an invalid sign-in address"
    end
    session[:horizon_oauth_state] = state
    session[:horizon_oauth_started_at] = Time.current.to_i
    redirect_to uri.to_s, allow_other_host: true, inertia: { full_page: true }
  rescue KeyError, URI::InvalidURIError
    raise Horizon::Client::ResponseError, "Horizon returned an invalid sign-in address"
  end

  def callback
    response.set_header("Referrer-Policy", "no-referrer")
    response.set_header("Cache-Control", "no-store")
    state = session.delete(:horizon_oauth_state)
    started_at = session.delete(:horizon_oauth_started_at).to_i
    unless state.present? && started_at > 10.minutes.ago.to_i && ActiveSupport::SecurityUtils.secure_compare(state, params[:state].to_s)
      raise Horizon::Client::Error, "Horizon authorization expired. Start the connection again."
    end
    codes = (params[:authorization_codes].presence || params[:authorization_code]).to_s.split(",").map(&:strip)
    raise Horizon::Client::Error, "Horizon did not return an authorization code." if codes.empty? || codes.any?(&:blank?) || codes.uniq.size != codes.size
    HorizonConnection.transaction do
      raise Horizon::Client::Error, "A Horizon connection already exists. Disconnect it before reconnecting." if HorizonConnection.exists?
      codes.each { |code| HorizonConnection.create!(authorization_code: code) }
    end
    redirect_to edit_season_path(current_season), notice: "Horizon authorized. Test read access for each organization below."
  end

  def test
    connection = HorizonConnection.find(params[:id])
    client = Horizon::Client.new(access_token: connection.access_token_for_request)
    result = client.schedule.list(start_date: Date.current.iso8601, end_date: Date.current.iso8601)
    raise Horizon::Client::ResponseError, "Horizon returned an unexpected schedule response" unless result["result"].is_a?(Array)
    redirect_to edit_season_path(current_season), notice: "Horizon read access succeeded. Today's first page contains #{result['result'].size} events."
  end

  def disconnect
    HorizonGameSync.delete_all
    HorizonConnection.destroy_all
    redirect_to edit_season_path(current_season), notice: "Horizon disconnected from InvoiceMe. Revoke access in Horizon if desired."
  end

  private

  def horizon_error(error)
    redirect_to(current_season ? edit_season_path(current_season) : root_path, alert: error.message)
  end
end
