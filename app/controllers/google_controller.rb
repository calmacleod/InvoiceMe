class GoogleController < ApplicationController
  def connect
    raise GoogleApi::Error, "Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET on the server first" unless GoogleApi.configured?
    session[:oauth_state] = SecureRandom.hex(32)
    query = { client_id: ENV.fetch("GOOGLE_CLIENT_ID"), redirect_uri: GoogleApi.redirect_uri, response_type: "code", scope: GoogleApi::SCOPES, access_type: "offline", prompt: "consent", state: session[:oauth_state], login_hint: ENV.fetch("GOOGLE_ALLOWED_EMAIL", "treasurer@eotfoa.ca") }
    redirect_to "https://accounts.google.com/o/oauth2/v2/auth?#{URI.encode_www_form(query)}", allow_other_host: true, inertia: { full_page: true }
  end
  def callback
    state = session.delete(:oauth_state)
    raise GoogleApi::Error, "Google sign-in expired. Try connecting again." unless state.present? && ActiveSupport::SecurityUtils.secure_compare(state, params[:state].to_s) && params[:code].present?
    token = GoogleApi.token(GoogleApi.oauth_params.merge(code: params[:code], grant_type: "authorization_code"))
    client = GoogleApi.allocate
    client.instance_variable_set(:@access_token, token.fetch("access_token"))
    profile = client.request(:get, "https://openidconnect.googleapis.com/v1/userinfo")
    allowed = ENV.fetch("GOOGLE_ALLOWED_EMAIL", "treasurer@eotfoa.ca")
    raise GoogleApi::Error, "Please connect #{allowed}" unless profile["email_verified"] && profile["email"].to_s.casecmp?(allowed)
    raise GoogleApi::Error, "Google did not provide offline access. Reconnect with consent." unless token["refresh_token"].present?
    connection = GoogleConnection.first || GoogleConnection.new
    connection.update!(email: profile.fetch("email"), refresh_token: token.fetch("refresh_token"))
    redirect_to edit_season_path(current_season), notice: "Connected #{connection.email}"
  end
  def disconnect
    GoogleConnection.destroy_all
    redirect_to edit_season_path(current_season), notice: "Google account disconnected from InvoiceMe"
  end
end
